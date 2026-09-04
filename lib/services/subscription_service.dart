import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/subscription_model.dart';
import '../screens/subscription_screen.dart';

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;

  // ── Firestore stream ────────────────────────────────────────────────────────

  Stream<SubscriptionModel> watchSubscription(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return SubscriptionModel.inactive;
      return SubscriptionModel.fromMap(data['subscription'] as Map<String, dynamic>?) ??
          SubscriptionModel.inactive;
    });
  }

  Future<bool> hasActiveSubscription(String uid) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data();
      if (data == null) return false;
      return SubscriptionModel.fromMap(data['subscription'] as Map<String, dynamic>?)
              ?.isActive ??
          false;
    } catch (_) {
      return false;
    }
  }

  // ── Stripe Cloud Functions ──────────────────────────────────────────────────

  /// Calls the `createCheckoutSession` Cloud Function and returns the Stripe Checkout URL.
  Future<String?> createCheckoutSession({
    required String successUrl,
    required String cancelUrl,
  }) async {
    try {
      final callable = _functions.httpsCallable('createCheckoutSession');
      final result = await callable.call<Map>({
        'successUrl': successUrl,
        'cancelUrl': cancelUrl,
      });
      return result.data['url'] as String?;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('createCheckoutSession error: ${e.code} — ${e.message}');
      return null;
    } catch (e) {
      debugPrint('createCheckoutSession unexpected error: $e');
      return null;
    }
  }

  /// Calls the `createPortalSession` Cloud Function and returns the Stripe Portal URL.
  Future<String?> createPortalSession({required String returnUrl}) async {
    try {
      final callable = _functions.httpsCallable('createPortalSession');
      final result = await callable.call<Map>({'returnUrl': returnUrl});
      return result.data['url'] as String?;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('createPortalSession error: ${e.code} — ${e.message}');
      return null;
    } catch (e) {
      debugPrint('createPortalSession unexpected error: $e');
      return null;
    }
  }

  // ── Guard ───────────────────────────────────────────────────────────────────

  /// Shows SubscriptionScreen if user is not subscribed; calls [onAllowed] immediately if they are.
  Future<void> requireSubscription(
    BuildContext context, {
    required VoidCallback onAllowed,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
      }
      return;
    }

    final active = await hasActiveSubscription(user.uid);

    if (!context.mounted) return;

    if (active) {
      onAllowed();
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      );
    }
  }
}
