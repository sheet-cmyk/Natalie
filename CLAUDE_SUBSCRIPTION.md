# Claude Project Instruction — Subscription System

## Important
This file is part of the existing Flutter project.

Claude must read this file before making changes related to subscriptions, paid access, publishing permissions, profile access, Stripe, Google Play Billing, Apple subscriptions, Firebase subscription state, notifications, or email reminders.

Treat this file as the persistent source of truth for this feature.

Before each related implementation step:
1. Re-read this file.
2. Inspect the current project state.
3. Continue from the existing implementation.
4. Do not rebuild completed work.
5. Do not remove or replace working functionality unless required.
6. If implementation decisions change, update this same file with the new final state and progress.

## Project Context
The application is already complete and built with Flutter and Firebase.

It also supports Web.

Do NOT rebuild the application.

Do NOT redesign unrelated screens.

Do NOT replace the current architecture unless technically necessary.

The goal is only to add a real monthly subscription system to the existing application.

## App Concept
This is a marriage-focused application.

Men and women can create and publish their profile/post for marriage.

Users can browse existing posts without having an active subscription.

## Access Rules

### Guest User
A guest can:
- Open the app.
- Browse the home page.
- See public post cards and public information.

A guest cannot:
- Publish a marriage profile/post.
- Open the complete profile/details page of another published member.
- Access subscriber-only features.

If a guest tries to publish or open a protected full profile:
- Show the subscription/paywall page.

If authentication is required before payment, preserve the existing authentication flow and return the user to the subscription flow afterward.

### Logged-in User Without Subscription
A logged-in user without an active subscription can:
- Sign in normally.
- Use Google Sign-In and all other existing authentication methods.
- Browse the home page.
- See public post cards.

They cannot:
- Create or publish their marriage profile/post.
- Open complete profile/details pages of published users.
- Use subscriber-only functionality.

When they try to perform a protected action:
- Redirect them to the subscription page.

### Active Subscriber
An active subscriber can:
- Publish their marriage profile/post.
- Edit their published profile.
- Open complete profiles/details.
- Use all features marked as subscriber-only.

## Subscription
Implement a monthly recurring subscription.

Create a dedicated subscription/paywall screen matching the existing app design.

The subscription page should contain:
- Monthly price.
- Subscription benefits.
- Subscribe button.
- Current subscription status.
- Renewal/expiration date when available.
- Restore purchase option where applicable.
- Manage subscription option where applicable.

## Core Security Rule
Do NOT protect paid functionality only with Flutter UI checks.

Never rely on a local value such as:

```dart
isPremium = true;
```

Subscription entitlement must be verified securely.

Firebase/backend must be the trusted source for subscription entitlement.

Suggested structure:

```text
users/{uid}
  subscription:
    status: active | inactive | expired | canceled
    provider: stripe | google_play | apple
    plan: monthly
    expiresAt: Timestamp
    updatedAt: Timestamp
```

Adapt this structure to the existing project architecture if another structure is already more suitable.

Do not introduce unnecessary database migrations.

## Firebase Protection
Protect subscriber-only operations on the backend / Firebase Security Rules.

A non-subscriber must not be able to bypass Flutter and directly:
- Create/publish protected posts.
- Access protected full-profile data.
- Perform subscriber-only operations.

Keep public preview data readable to guests/non-subscribers.

If the existing Firestore document exposes both public and protected fields in a way that cannot be secured safely, minimally separate them into:
- Public profile/post data.
- Protected/full profile data.

Do not destroy or lose existing data.

## Platform Payments
Use the correct subscription provider for each platform.

### Web
Use Stripe monthly subscriptions.

### Android
Use Google Play Billing subscriptions.

### iOS
Use Apple auto-renewable subscriptions.

Do not implement a payment approach that violates store billing requirements.

## Unified Flutter Subscription Layer
Create or adapt a single subscription/entitlement service.

Example naming:

```text
SubscriptionService
EntitlementService
```

The rest of the app should depend on a unified state such as:

```dart
subscriptionService.hasActiveSubscription
```

UI screens should not need to know whether payment came from Stripe, Google Play, or Apple.

## Backend Verification
Implement secure server-side verification for:
- Stripe webhooks.
- Google Play subscriptions.
- Apple subscriptions.

Do not trust purchase state sent only from the client.

After successful verification:
- Update the user's trusted subscription status in Firebase.

## Expired or Canceled Subscription
When the subscription expires or is canceled:
- Keep the user's account.
- Keep their previously published profile/data.
- Do not automatically delete their data.
- Block new subscriber-only operations.
- Block access to protected full profiles.
- Redirect protected actions to the subscription page.

## Notifications and Email
Prepare the system for:
- Subscription activated.
- Subscription renewed.
- Renewal approaching.
- Payment failed.
- Subscription canceled.
- Subscription expired.

Use Firebase Cloud Messaging for app push notifications where appropriate.

For email:
- Keep the email implementation modular.
- Do not hardcode fake API keys.
- If an email provider is not configured, implement the required interface/service and clearly report what external provider/configuration is still needed.

## Existing Project Integration
Before changing code, inspect the project and locate:
- Publish/Create Post action.
- Full profile/details navigation.
- Existing authentication flow.
- User model.
- Post/profile model.
- Firebase services.
- Firestore collections.
- Routing/navigation.
- State management.
- Existing Cloud Functions/backend if present.
- Existing notification implementation if present.

Reuse the current architecture.

If the project uses Provider, Riverpod, Bloc, GetX, or another solution:
- Continue using that solution.

Do not introduce a second state-management architecture without a strong technical reason.

## Subscription Guard
Create one reusable subscription guard instead of repeating checks across many screens.

Example concept:

```dart
requireSubscription(
  onAllowed: () {
    // Continue protected action
  },
);
```

Required behavior:

```text
if subscription is active:
    continue
else:
    open subscription page
```

Apply it at least to:
- Publish/Create Profile.
- Edit protected publishing actions where appropriate.
- Open Full Profile.

Also enforce the same permissions on the backend.

## Do Not Break Existing Functionality
Do not:
- Remove existing authentication.
- Redesign the whole app.
- Rename Firebase collections unnecessarily.
- Delete existing Firebase data.
- Replace working code unnecessarily.
- Add production mock subscription states.
- Break Web, Android, or iOS behavior.
- Rebuild unrelated parts of the project.

Preserve backward compatibility wherever possible.

## Implementation Order

### Phase 1 — Project Inspection
Inspect the existing project and document:
- Relevant files.
- Current authentication architecture.
- Current user/profile/post architecture.
- Firestore collections.
- State management.
- Navigation.
- Backend/Cloud Functions.
- Exact places where subscription protection must be inserted.

### Phase 2 — Subscription Model
Implement/adapt:
- Subscription data model.
- Entitlement state.
- Subscription service.

### Phase 3 — Paywall
Create the subscription page using the existing app theme/components.

### Phase 4 — App Guards
Protect:
- Publishing.
- Creating a marriage profile.
- Opening full member profiles.

### Phase 5 — Backend Security
Implement:
- Server verification.
- Firebase/Firestore protection.
- Required Security Rules.

### Phase 6 — Web
Implement Stripe monthly subscription for Web.

### Phase 7 — Android
Implement Google Play Billing subscription.

### Phase 8 — iOS
Implement Apple auto-renewable subscription.

### Phase 9 — Notifications
Implement subscription push/email event handling.

### Phase 10 — Testing
Test:
- Guest browsing.
- Guest tries to publish.
- Guest tries to open full profile.
- Logged-in non-subscriber browsing.
- Logged-in non-subscriber tries to publish.
- Logged-in non-subscriber opens full profile.
- Active subscriber publishes.
- Active subscriber opens full profiles.
- Expired subscription.
- Canceled subscription.
- Failed renewal.
- Restore purchase.
- Logout/login after subscription.
- Subscription recognized on another device.
- Web subscription state synchronized correctly.
- Direct Firebase access cannot bypass entitlement rules.

## Persistent Progress Section
Claude must maintain this section during implementation.

Update it after each completed phase.

### Current Status
- Phase 1: ✅ Complete — project inspection done
- Phase 2: ✅ Complete — lib/models/subscription_model.dart + lib/services/subscription_service.dart
- Phase 3: ✅ Complete — lib/screens/subscription_screen.dart (MSA1.png background, gold crown, price card, benefits, subscribe button + manage subscription link)
- Phase 4: ✅ Complete — guards added to home_screen.dart (card tap) and ad_screen.dart (_requestPublish)
- Phase 5: ✅ Complete — firestore.rules updated: subscription field locked to admin-only writes; pendingPublish/published locked from user self-update
- Phase 6: ✅ Complete — Stripe Web integration via Firebase Cloud Functions (createCheckoutSession, stripeWebhook, createPortalSession); Flutter calls function → gets checkout URL → opens in browser; webhook updates Firestore automatically
- Phase 7: Not started
- Phase 8: Not started
- Phase 9: Not started
- Phase 10: Not started

### Important Decisions
- No Provider/Riverpod — SubscriptionService is a singleton with static `.instance`
- `requireSubscription()` is async; onAllowed callback is sync VoidCallback
- Web Stripe flow: server-side Checkout Sessions (no Stripe SDK in Flutter needed for web)
- Firebase Cloud Functions (gen1) used — predictable webhook URL: https://us-central1-om-natalie.cloudfunctions.net/stripeWebhook
- Stripe secrets stored in Firebase Secrets Manager (never in source code)
- Firebase UID passed via Stripe metadata on both checkout session and subscription_data
- Stripe Customer ID stored in users/{uid}.stripeCustomerId (written server-side, bypasses rules)
- Success redirect: natalie-zain.web.app/?subscription=success — home_screen detects and shows snackbar
- Publishable key NOT needed in Flutter for server-side checkout (only needed later for Android/iOS native SDKs)
- Price (9.99$/month) hardcoded in subscription_screen.dart — can be moved to Firestore config later

### Stripe Setup Steps (user must complete)
1. In Stripe Dashboard → Products → Create "لقاء Monthly" → Add price: $9.99/month recurring → copy Price ID
2. In Stripe Dashboard → Developers → API Keys → copy Secret Key (sk_live_...) and Publishable Key
3. Deploy functions first: `cd functions && npm install` then `firebase deploy --only functions`
4. In Stripe Dashboard → Developers → Webhooks → Add endpoint:
   URL: https://us-central1-om-natalie.cloudfunctions.net/stripeWebhook
   Events: checkout.session.completed, customer.subscription.updated, customer.subscription.deleted, invoice.paid, invoice.payment_failed
5. Copy the Webhook Signing Secret (whsec_...)
6. Set secrets via CLI:
   `firebase functions:secrets:set STRIPE_SECRET_KEY`
   `firebase functions:secrets:set STRIPE_WEBHOOK_SECRET`
   `firebase functions:secrets:set STRIPE_PRICE_ID`
7. In Stripe Dashboard → Settings → Billing → Customer Portal → Enable portal features
8. Redeploy functions: `firebase deploy --only functions`
9. Build and deploy web: `flutter build web --release` then `firebase deploy --only hosting`

### Remaining Manual Stripe Dashboard Steps
- [x] Create product + price ($9.99/month) → price_1UC0u0Dpf8rCe6DFDXU7975j
- [x] Set STRIPE_PRICE_ID secret
- [x] Set STRIPE_SECRET_KEY secret
- [x] Register webhook at https://us-central1-om-natalie.cloudfunctions.net/stripeWebhook
- [x] Set STRIPE_WEBHOOK_SECRET secret
- [x] Deploy functions (all 3 live, Node 22 gen2, us-central1)
- [x] Build + deploy Flutter web to natalie-zain.web.app
- [ ] Enable Stripe Customer Portal → dashboard.stripe.com/settings/billing/portal (required for "إدارة الاشتراك" button)

### Files Changed
- lib/models/subscription_model.dart — NEW (Phase 2)
- lib/services/subscription_service.dart — UPDATED (Phase 6: added createCheckoutSession, createPortalSession)
- lib/screens/subscription_screen.dart — UPDATED (Phase 6: real Stripe checkout flow + manage subscription button)
- lib/screens/home_screen.dart — UPDATED (Phase 4: guard; Phase 6: Stripe success/cancel redirect detection)
- lib/screens/ad_screen.dart — UPDATED (Phase 4: subscription check in _requestPublish)
- firestore.rules — UPDATED (Phase 5: protected subscription + pendingPublish fields)
- functions/index.js — NEW (Phase 6: createCheckoutSession + stripeWebhook + createPortalSession)
- functions/package.json — NEW (Phase 6: firebase-functions, firebase-admin, stripe)
- functions/.gitignore — NEW
- firebase.json — UPDATED (Phase 6: functions source added)
- pubspec.yaml — UPDATED (Phase 6: cloud_functions ^5.1.3)
- .gitignore — UPDATED (functions/node_modules excluded)

### Remaining External Setup
List any actions I must perform manually, such as:
- Stripe keys/products/webhook secrets.
- Google Play subscription product configuration.
- Apple subscription product configuration.
- Firebase secrets.
- Email provider credentials.

## Final Instruction
Start by reading this entire file and inspecting the existing project.

Do not blindly rewrite files.

Continue from the project's current state.

For all future work related to this subscription feature, treat this Markdown file as the persistent reference and update its progress section so another Claude session can continue from the same project without losing the implementation context.
