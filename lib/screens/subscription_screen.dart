import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/subscription_service.dart';

// Stripe publishable key — safe to commit (public key only, never secret).
// Current value: TEST mode. Replace with pk_live_... before going to production.
// Needed in Phase 7 (Android) and Phase 8 (iOS) for native Stripe SDKs.
// For web Checkout (server-side sessions), this key is NOT used at runtime.
const kStripePublishableKey =
    'pk_test_51UBGhTDpf8rCe6DFxXx0WiGT4XlZRnNCNFtR6AuSROcv2YRR8xyeCgN6hk4drmVaARKl3Saa8IMSbNkMPMeoPymU00c1BqxyZt';

const _kSuccessUrl = 'https://natalie-zain.web.app/?subscription=success';
const _kCancelUrl  = 'https://natalie-zain.web.app/?subscription=canceled';
const _kReturnUrl  = 'https://natalie-zain.web.app/';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _loadingCheckout = false;
  bool _loadingPortal = false;
  String? _error;

  static const List<String> _benefits = [
    'عرض الملفات الشخصية كاملة',
    'نشر ملفك الشخصي للزواج',
    'تعديل ملفك الشخصي في أي وقت',
    'التواصل عبر الرسائل والدردشة',
    'الوصول لجميع مميزات التطبيق',
  ];

  Future<void> _startCheckout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      setState(() => _error = 'يجب تسجيل الدخول أولاً');
      return;
    }

    setState(() { _loadingCheckout = true; _error = null; });

    try {
      final url = await SubscriptionService.instance.createCheckoutSession(
        successUrl: _kSuccessUrl,
        cancelUrl:  _kCancelUrl,
      );

      if (!mounted) return;

      if (url == null || url.isEmpty) {
        setState(() => _error = 'حدث خطأ أثناء إنشاء جلسة الدفع. حاول مرة أخرى.');
        return;
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        setState(() => _error = 'تعذّر فتح صفحة الدفع.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'خطأ: $e');
    } finally {
      if (mounted) setState(() => _loadingCheckout = false);
    }
  }

  Future<void> _openPortal() async {
    setState(() { _loadingPortal = true; _error = null; });

    try {
      final url = await SubscriptionService.instance.createPortalSession(
        returnUrl: _kReturnUrl,
      );

      if (!mounted) return;

      if (url == null || url.isEmpty) {
        setState(() => _error = 'تعذّر فتح بوابة الاشتراك.');
        return;
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'خطأ: $e');
    } finally {
      if (mounted) setState(() => _loadingPortal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null || user.isAnonymous;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/Image/MSA1.png', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.60)),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      children: [
                        const _CrownIcon(),
                        const SizedBox(height: 20),
                        const Text(
                          'اشتراك لقاء',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'احصل على صلاحيات كاملة وابدأ رحلتك',
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        const _PriceCard(),
                        const SizedBox(height: 24),
                        ..._benefits.map((b) => _BenefitRow(text: b)),
                        const SizedBox(height: 32),

                        // Error message
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Subscribe button (shown for non-subscribers)
                        if (!isGuest || kIsWeb)
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _loadingCheckout ? null : _startCheckout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE8758A),
                                disabledBackgroundColor:
                                    const Color(0xFFE8758A).withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 6,
                                shadowColor:
                                    const Color(0xFFE8758A).withValues(alpha: 0.5),
                              ),
                              child: _loadingCheckout
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'اشترك الآن — 9.99\$',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Manage subscription (Stripe Customer Portal)
                        if (!isGuest)
                          TextButton(
                            onPressed: _loadingPortal ? null : _openPortal,
                            child: _loadingPortal
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white54,
                                    ),
                                  )
                                : const Text(
                                    'إدارة الاشتراك',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.white54,
                                    ),
                                  ),
                          ),

                        if (!isGuest)
                          const Padding(
                            padding: EdgeInsets.only(top: 8, bottom: 12),
                            child: Text(
                              'بعد الدفع سيتم تفعيل اشتراكك تلقائياً خلال ثوانٍ',
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CrownIcon extends StatelessWidget {
  const _CrownIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: const Icon(
        Icons.workspace_premium_rounded,
        color: Color(0xFFFFD700),
        size: 52,
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE8758A).withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'اشتراك شهري',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: '9.99',
                  style: TextStyle(
                    color: Color(0xFFE8758A),
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: ' \$',
                  style: TextStyle(
                    color: Color(0xFFE8758A),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'في الشهر — يُجدَّد تلقائياً',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String text;
  const _BenefitRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFE8758A).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Color(0xFFE8758A), size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
