'use strict';

const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const Stripe = require('stripe');

admin.initializeApp();
const db = admin.firestore();

// Secrets — values injected at runtime from Firebase Secret Manager
const stripeSecretKey     = defineSecret('STRIPE_SECRET_KEY');
const stripeWebhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');
const stripePriceId       = defineSecret('STRIPE_PRICE_ID');

// ── helpers ────────────────────────────────────────────────────────────────────

function stripeClient(sk) {
  return new Stripe(sk, { apiVersion: '2025-01-27.acacia' });
}

async function getOrCreateCustomer(uid, email, sk) {
  const snap = await db.collection('users').doc(uid).get();
  const existing = (snap.data() || {}).stripeCustomerId;
  if (existing) return existing;

  const customer = await stripeClient(sk).customers.create({
    email: email || undefined,
    metadata: { firebaseUID: uid },
  });

  await db.collection('users').doc(uid).update({ stripeCustomerId: customer.id });
  return customer.id;
}

async function setSubscription(uid, sub, status) {
  await db.collection('users').doc(uid).update({
    subscription: {
      status,
      provider: 'stripe',
      plan: 'monthly',
      stripeSubscriptionId: sub.id,
      expiresAt: admin.firestore.Timestamp.fromMillis(sub.current_period_end * 1000),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  });
}

async function patchStatus(uid, status) {
  await db.collection('users').doc(uid).update({
    'subscription.status': status,
    'subscription.updatedAt': admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function handleWebhookEvent(event, sk) {
  const s = stripeClient(sk);

  switch (event.type) {

    case 'checkout.session.completed': {
      const session = event.data.object;
      if (session.mode !== 'subscription') return;
      const uid = (session.metadata || {}).firebaseUID;
      if (!uid) { console.warn('checkout.session.completed: no firebaseUID'); return; }
      const sub = await s.subscriptions.retrieve(session.subscription);
      await setSubscription(uid, sub, 'active');
      console.log(`Activated subscription for ${uid}`);
      break;
    }

    case 'invoice.paid': {
      const inv = event.data.object;
      if (!inv.subscription) return;
      const sub = await s.subscriptions.retrieve(inv.subscription);
      const uid = (sub.metadata || {}).firebaseUID;
      if (!uid) return;
      await setSubscription(uid, sub, 'active');
      console.log(`Renewed subscription for ${uid}`);
      break;
    }

    case 'invoice.payment_failed': {
      const inv = event.data.object;
      if (!inv.subscription) return;
      const sub = await s.subscriptions.retrieve(inv.subscription);
      const uid = (sub.metadata || {}).firebaseUID;
      if (!uid) return;
      await patchStatus(uid, 'inactive');
      console.log(`Payment failed for ${uid}`);
      break;
    }

    case 'customer.subscription.updated': {
      const sub = event.data.object;
      const uid = (sub.metadata || {}).firebaseUID;
      if (!uid) return;
      const status = sub.status === 'active' ? 'active' : 'inactive';
      await setSubscription(uid, sub, status);
      console.log(`Subscription updated for ${uid} -> ${status}`);
      break;
    }

    case 'customer.subscription.deleted': {
      const sub = event.data.object;
      const uid = (sub.metadata || {}).firebaseUID;
      if (!uid) return;
      await patchStatus(uid, 'canceled');
      console.log(`Subscription canceled for ${uid}`);
      break;
    }

    default:
      break;
  }
}

// ── Cloud Function 1: createCheckoutSession ───────────────────────────────────

exports.createCheckoutSession = onCall(
  { secrets: [stripeSecretKey, stripePriceId] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in');
    }

    const uid      = request.auth.uid;
    const email    = request.auth.token.email || request.auth.token.phone_number;
    const { successUrl, cancelUrl } = request.data;

    if (!successUrl || !cancelUrl) {
      throw new HttpsError('invalid-argument', 'successUrl and cancelUrl required');
    }

    const sk       = stripeSecretKey.value();
    const priceId  = stripePriceId.value();
    const customerId = await getOrCreateCustomer(uid, email, sk);

    const session = await stripeClient(sk).checkout.sessions.create({
      customer: customerId,
      payment_method_types: ['card'],
      mode: 'subscription',
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: successUrl,
      cancel_url:  cancelUrl,
      metadata: { firebaseUID: uid },
      subscription_data: { metadata: { firebaseUID: uid } },
    });

    return { url: session.url };
  },
);

// ── Cloud Function 2: stripeWebhook ──────────────────────────────────────────

exports.stripeWebhook = onRequest(
  { secrets: [stripeSecretKey, stripeWebhookSecret] },
  async (req, res) => {
    const sig = req.headers['stripe-signature'];
    const sk  = stripeSecretKey.value();
    const whs = stripeWebhookSecret.value();

    let event;
    try {
      event = stripeClient(sk).webhooks.constructEvent(req.rawBody, sig, whs);
    } catch (err) {
      console.error('Webhook signature failed:', err.message);
      return res.status(400).send('Webhook Error: ' + err.message);
    }

    try {
      await handleWebhookEvent(event, sk);
      res.json({ received: true });
    } catch (err) {
      console.error('Webhook handler error:', err);
      res.status(500).send('Internal server error');
    }
  },
);

// ── Cloud Function 3: createPortalSession ────────────────────────────────────

exports.createPortalSession = onCall(
  { secrets: [stripeSecretKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in');
    }

    const uid       = request.auth.uid;
    const returnUrl = (request.data || {}).returnUrl || 'https://natalie-zain.web.app/';
    const sk        = stripeSecretKey.value();

    const snap = await db.collection('users').doc(uid).get();
    const customerId = (snap.data() || {}).stripeCustomerId;

    if (!customerId) {
      throw new HttpsError('not-found', 'No Stripe customer linked to this account');
    }

    const portalSession = await stripeClient(sk).billingPortal.sessions.create({
      customer: customerId,
      return_url: returnUrl,
    });

    return { url: portalSession.url };
  },
);
