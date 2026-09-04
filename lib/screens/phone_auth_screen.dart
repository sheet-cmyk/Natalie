import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  String _countryCode = '+964';
  String _countryFlag = '🇮🇶';

  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;
  String? _verificationId;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // ── Send OTP ──────────────────────────────────────────────────────────────
  Future<void> _sendCode() async {
    final number = _phoneCtrl.text.trim();
    if (number.isEmpty || number.length < 5) {
      setState(() => _error = 'أدخل رقم هاتف صحيح');
      return;
    }
    setState(() { _loading = true; _error = null; });

    // في وضع التطوير: تجاوز التحقق التلقائي (يسمح باستخدام أرقام الاختبار)
    if (kDebugMode) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '$_countryCode$number',
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential cred) async {
        await _finishSignIn(cred);
      },
      verificationFailed: (FirebaseAuthException e) {
        String msg;
        switch (e.code) {
          case 'operation-not-allowed':
            msg = 'Phone Auth غير مفعّل في Firebase Console';
          case 'invalid-phone-number':
            msg = 'رقم الهاتف غير صحيح، تأكد من صيغته';
          case 'too-many-requests':
            msg = 'طلبات كثيرة جداً، انتظر دقيقة وأعد المحاولة';
          case 'quota-exceeded':
            msg = 'تم تجاوز حد الرسائل، حاول لاحقاً';
          default:
            msg = e.message ?? 'فشل إرسال الرمز (${e.code})';
        }
        if (mounted) setState(() { _loading = false; _error = msg; });
      },
      codeSent: (String verificationId, int? resendToken) {
        if (mounted) setState(() { _loading = false; _codeSent = true; _verificationId = verificationId; });
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────
  Future<void> _verifyCode() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) { setState(() => _error = 'الرمز يجب أن يكون 6 أرقام'); return; }
    if (_verificationId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final cred = PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: otp);
      await _finishSignIn(cred);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'رمز غير صحيح: ${e.message}'; });
    }
  }

  Future<void> _finishSignIn(PhoneAuthCredential cred) async {
    try {
      final r = await FirebaseAuth.instance.signInWithCredential(cred);
      await _ensureUserRecord(r.user!);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'فشل تسجيل الدخول'; });
    }
  }

  Future<void> _ensureUserRecord(User user) async {
    final db = FirebaseFirestore.instance;
    final doc = await db.collection('users').doc(user.uid).get();
    if (doc.exists && (doc.data()?['username'] as String?)?.isNotEmpty == true) return;
    final id = 'user${user.uid.substring(0, 8)}';
    final batch = db.batch();
    batch.set(db.collection('users').doc(user.uid), {
      'email': '', 'name': '', 'username': id, 'age': 0, 'bio': '',
      'whatsapp': '', 'facebook': '', 'tiktok': '', 'instagram': '',
      'photoUrls': [], 'published': false, 'blocked': false,
      'pendingPublish': false, 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(db.collection('usernames').doc(id), {'uid': user.uid, 'createdAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CountryPickerSheet(
        selectedCode: _countryCode,
        onSelected: (code, flag) => setState(() { _countryCode = code; _countryFlag = flag; }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/Image/MSA1.png', fit: BoxFit.cover),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildContent()),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 14, top: 8),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 6)],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFE91E8C), size: 18),
                  ),
                ),
              ),
            ),
          ),
          if (_loading) ...[
            Container(color: Colors.black.withValues(alpha: 0.35)),
            const Center(child: CircularProgressIndicator(color: Color(0xFFE91E8C), strokeWidth: 3)),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 1. حقل رقم الهاتف ────────────────────────────────────
            _buildPhoneField(),
            const SizedBox(height: 12),

            // ── 2. زر الحصول على الرمز ────────────────────────────────
            _buildGetCodeButton(),
            const SizedBox(height: 12),

            // ── 3. حقل الرمز (ظاهر دائماً) ────────────────────────────
            _buildOtpField(),

            // ── Error ─────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 14),
                  const SizedBox(width: 4),
                  Flexible(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // ── 4. زر التالي ──────────────────────────────────────────
            _buildVerifyButton(),
          ],
        ),
      ),
    );
  }

  // ── حقل رقم الهاتف مع منتقي الدولة ──────────────────────────────────────
  Widget _buildPhoneField() {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          // ── منتقي الدولة ──────────────────────────────────────────
          GestureDetector(
            onTap: (_loading || _codeSent) ? null : _showCountryPicker,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_countryFlag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 4),
                  Text(_countryCode, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _codeSent ? Colors.grey.shade300 : const Color(0xFF888888),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 34, color: Colors.grey.shade300),
          // ── حقل الأرقام ───────────────────────────────────────────
          Expanded(
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              enabled: !_loading && !_codeSent,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: 18,
                color: _codeSent ? Colors.grey.shade500 : const Color(0xFF333333),
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
              onChanged: (_) { if (_error != null) setState(() => _error = null); },
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'رقم الهاتف',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── زر "الحصول على الرمز" ────────────────────────────────────────────────
  Widget _buildGetCodeButton() {
    final pink = const Color(0xFFE91E8C);
    final sent = _codeSent;
    return GestureDetector(
      onTap: (_loading || sent) ? null : _sendCode,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: sent ? Colors.green.withValues(alpha: 0.5) : pink.withValues(alpha: 0.30),
            width: 1.3,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              sent ? Icons.check_circle_rounded : Icons.sms_outlined,
              color: sent ? Colors.green : pink,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              sent ? 'تم إرسال الرمز  ✓' : 'الحصول على الرمز',
              style: TextStyle(
                color: sent ? Colors.green.shade700 : pink,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── حقل الرمز (ظاهر دائماً) ─────────────────────────────────────────────
  Widget _buildOtpField() {
    final pink = const Color(0xFFE91E8C);
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _codeSent ? pink.withValues(alpha: 0.65) : Colors.grey.shade300,
          width: _codeSent ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _codeSent ? pink.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              Icons.lock_outline_rounded,
              color: _codeSent ? pink.withValues(alpha: 0.8) : Colors.grey.shade400,
              size: 20,
            ),
          ),
          Container(width: 1, height: 34, color: _codeSent ? pink.withValues(alpha: 0.2) : Colors.grey.shade200),
          Expanded(
            child: TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              maxLength: 6,
              enabled: !_loading,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: 26,
                letterSpacing: 10,
                fontWeight: FontWeight.bold,
                color: _codeSent ? pink : Colors.grey.shade400,
              ),
              onChanged: (v) {
                if (_error != null) setState(() => _error = null);
                if (v.length == 6 && _codeSent) _verifyCode();
              },
              decoration: InputDecoration(
                counterText: '',
                border: InputBorder.none,
                hintText: '- - - - - -',
                hintStyle: TextStyle(
                  color: Colors.grey.shade300,
                  letterSpacing: 6,
                  fontSize: 18,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
          if (_codeSent)
            GestureDetector(
              onTap: _loading ? null : () {
                setState(() { _codeSent = false; _verificationId = null; _otpCtrl.clear(); _error = null; });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('إعادة', style: TextStyle(color: pink.withValues(alpha: 0.7), fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  // ── زر التحقق (يظهر فقط بعد إرسال الرمز) ────────────────────────────────
  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: ElevatedButton(
        onPressed: _loading ? null : _verifyCode,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE8758A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE8758A).withValues(alpha: 0.5),
          elevation: 6,
          shadowColor: const Color(0xFFE8758A).withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: _loading
            ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(left: 16, child: Icon(Icons.spa_rounded, color: Colors.white.withValues(alpha: 0.4), size: 20)),
                  Positioned(right: 16, child: Icon(Icons.spa_rounded, color: Colors.white.withValues(alpha: 0.4), size: 20)),
                  const Text('التالي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ],
              ),
      ),
    );
  }
}

// ─── Country Picker Sheet ─────────────────────────────────────────────────────

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.selectedCode, required this.onSelected});
  final String selectedCode;
  final void Function(String code, String flag) onSelected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();

  // ── All world countries ─────────────────────────────────────────────────
  static const List<Map<String, String>> allCountries = [
    // ── الدول العربية ──────────────────────────────────────────────────────
    {'code': '+964', 'flag': '🇮🇶', 'name': 'العراق'},
    {'code': '+966', 'flag': '🇸🇦', 'name': 'السعودية'},
    {'code': '+971', 'flag': '🇦🇪', 'name': 'الإمارات'},
    {'code': '+962', 'flag': '🇯🇴', 'name': 'الأردن'},
    {'code': '+965', 'flag': '🇰🇼', 'name': 'الكويت'},
    {'code': '+974', 'flag': '🇶🇦', 'name': 'قطر'},
    {'code': '+973', 'flag': '🇧🇭', 'name': 'البحرين'},
    {'code': '+968', 'flag': '🇴🇲', 'name': 'عُمان'},
    {'code': '+20', 'flag': '🇪🇬', 'name': 'مصر'},
    {'code': '+963', 'flag': '🇸🇾', 'name': 'سوريا'},
    {'code': '+961', 'flag': '🇱🇧', 'name': 'لبنان'},
    {'code': '+218', 'flag': '🇱🇾', 'name': 'ليبيا'},
    {'code': '+216', 'flag': '🇹🇳', 'name': 'تونس'},
    {'code': '+212', 'flag': '🇲🇦', 'name': 'المغرب'},
    {'code': '+213', 'flag': '🇩🇿', 'name': 'الجزائر'},
    {'code': '+967', 'flag': '🇾🇪', 'name': 'اليمن'},
    {'code': '+249', 'flag': '🇸🇩', 'name': 'السودان'},
    {'code': '+970', 'flag': '🇵🇸', 'name': 'فلسطين'},
    {'code': '+252', 'flag': '🇸🇴', 'name': 'الصومال'},
    {'code': '+253', 'flag': '🇩🇯', 'name': 'جيبوتي'},
    {'code': '+222', 'flag': '🇲🇷', 'name': 'موريتانيا'},
    {'code': '+269', 'flag': '🇰🇲', 'name': 'جزر القمر'},
    // ── آسيا ──────────────────────────────────────────────────────────────
    {'code': '+90', 'flag': '🇹🇷', 'name': 'تركيا'},
    {'code': '+98', 'flag': '🇮🇷', 'name': 'إيران'},
    {'code': '+92', 'flag': '🇵🇰', 'name': 'باكستان'},
    {'code': '+91', 'flag': '🇮🇳', 'name': 'الهند'},
    {'code': '+880', 'flag': '🇧🇩', 'name': 'بنغلاديش'},
    {'code': '+94', 'flag': '🇱🇰', 'name': 'سريلانكا'},
    {'code': '+977', 'flag': '🇳🇵', 'name': 'نيبال'},
    {'code': '+93', 'flag': '🇦🇫', 'name': 'أفغانستان'},
    {'code': '+86', 'flag': '🇨🇳', 'name': 'الصين'},
    {'code': '+81', 'flag': '🇯🇵', 'name': 'اليابان'},
    {'code': '+82', 'flag': '🇰🇷', 'name': 'كوريا الجنوبية'},
    {'code': '+850', 'flag': '🇰🇵', 'name': 'كوريا الشمالية'},
    {'code': '+66', 'flag': '🇹🇭', 'name': 'تايلاند'},
    {'code': '+84', 'flag': '🇻🇳', 'name': 'فيتنام'},
    {'code': '+60', 'flag': '🇲🇾', 'name': 'ماليزيا'},
    {'code': '+62', 'flag': '🇮🇩', 'name': 'إندونيسيا'},
    {'code': '+63', 'flag': '🇵🇭', 'name': 'الفلبين'},
    {'code': '+65', 'flag': '🇸🇬', 'name': 'سنغافورة'},
    {'code': '+95', 'flag': '🇲🇲', 'name': 'ميانمار'},
    {'code': '+855', 'flag': '🇰🇭', 'name': 'كمبوديا'},
    {'code': '+856', 'flag': '🇱🇦', 'name': 'لاوس'},
    {'code': '+673', 'flag': '🇧🇳', 'name': 'بروناي'},
    {'code': '+886', 'flag': '🇹🇼', 'name': 'تايوان'},
    {'code': '+852', 'flag': '🇭🇰', 'name': 'هونغ كونغ'},
    {'code': '+976', 'flag': '🇲🇳', 'name': 'منغوليا'},
    {'code': '+7', 'flag': '🇷🇺', 'name': 'روسيا'},
    {'code': '+374', 'flag': '🇦🇲', 'name': 'أرمينيا'},
    {'code': '+994', 'flag': '🇦🇿', 'name': 'أذربيجان'},
    {'code': '+995', 'flag': '🇬🇪', 'name': 'جورجيا'},
    {'code': '+77', 'flag': '🇰🇿', 'name': 'كازاخستان'},
    {'code': '+996', 'flag': '🇰🇬', 'name': 'قيرغيزستان'},
    {'code': '+992', 'flag': '🇹🇯', 'name': 'طاجيكستان'},
    {'code': '+993', 'flag': '🇹🇲', 'name': 'تركمانستان'},
    {'code': '+998', 'flag': '🇺🇿', 'name': 'أوزبكستان'},
    {'code': '+972', 'flag': '🇮🇱', 'name': 'إسرائيل'},
    {'code': '+975', 'flag': '🇧🇹', 'name': 'بوتان'},
    {'code': '+960', 'flag': '🇲🇻', 'name': 'المالديف'},
    {'code': '+670', 'flag': '🇹🇱', 'name': 'تيمور الشرقية'},
    // ── أوروبا ────────────────────────────────────────────────────────────
    {'code': '+49', 'flag': '🇩🇪', 'name': 'ألمانيا'},
    {'code': '+44', 'flag': '🇬🇧', 'name': 'المملكة المتحدة'},
    {'code': '+33', 'flag': '🇫🇷', 'name': 'فرنسا'},
    {'code': '+31', 'flag': '🇳🇱', 'name': 'هولندا'},
    {'code': '+46', 'flag': '🇸🇪', 'name': 'السويد'},
    {'code': '+47', 'flag': '🇳🇴', 'name': 'النرويج'},
    {'code': '+45', 'flag': '🇩🇰', 'name': 'الدنمارك'},
    {'code': '+32', 'flag': '🇧🇪', 'name': 'بلجيكا'},
    {'code': '+41', 'flag': '🇨🇭', 'name': 'سويسرا'},
    {'code': '+43', 'flag': '🇦🇹', 'name': 'النمسا'},
    {'code': '+34', 'flag': '🇪🇸', 'name': 'إسبانيا'},
    {'code': '+39', 'flag': '🇮🇹', 'name': 'إيطاليا'},
    {'code': '+351', 'flag': '🇵🇹', 'name': 'البرتغال'},
    {'code': '+48', 'flag': '🇵🇱', 'name': 'بولندا'},
    {'code': '+420', 'flag': '🇨🇿', 'name': 'التشيك'},
    {'code': '+36', 'flag': '🇭🇺', 'name': 'هنغاريا'},
    {'code': '+40', 'flag': '🇷🇴', 'name': 'رومانيا'},
    {'code': '+30', 'flag': '🇬🇷', 'name': 'اليونان'},
    {'code': '+380', 'flag': '🇺🇦', 'name': 'أوكرانيا'},
    {'code': '+375', 'flag': '🇧🇾', 'name': 'بيلاروسيا'},
    {'code': '+372', 'flag': '🇪🇪', 'name': 'إستونيا'},
    {'code': '+371', 'flag': '🇱🇻', 'name': 'لاتفيا'},
    {'code': '+370', 'flag': '🇱🇹', 'name': 'ليتوانيا'},
    {'code': '+358', 'flag': '🇫🇮', 'name': 'فنلندا'},
    {'code': '+354', 'flag': '🇮🇸', 'name': 'آيسلندا'},
    {'code': '+353', 'flag': '🇮🇪', 'name': 'أيرلندا'},
    {'code': '+356', 'flag': '🇲🇹', 'name': 'مالطا'},
    {'code': '+385', 'flag': '🇭🇷', 'name': 'كرواتيا'},
    {'code': '+386', 'flag': '🇸🇮', 'name': 'سلوفينيا'},
    {'code': '+421', 'flag': '🇸🇰', 'name': 'سلوفاكيا'},
    {'code': '+387', 'flag': '🇧🇦', 'name': 'البوسنة والهرسك'},
    {'code': '+381', 'flag': '🇷🇸', 'name': 'صربيا'},
    {'code': '+382', 'flag': '🇲🇪', 'name': 'الجبل الأسود'},
    {'code': '+383', 'flag': '🇽🇰', 'name': 'كوسوفو'},
    {'code': '+355', 'flag': '🇦🇱', 'name': 'ألبانيا'},
    {'code': '+389', 'flag': '🇲🇰', 'name': 'مقدونيا الشمالية'},
    {'code': '+359', 'flag': '🇧🇬', 'name': 'بلغاريا'},
    {'code': '+373', 'flag': '🇲🇩', 'name': 'مولدوفا'},
    {'code': '+352', 'flag': '🇱🇺', 'name': 'لوكسمبورغ'},
    {'code': '+376', 'flag': '🇦🇩', 'name': 'أندورا'},
    {'code': '+377', 'flag': '🇲🇨', 'name': 'موناكو'},
    {'code': '+423', 'flag': '🇱🇮', 'name': 'ليختنشتاين'},
    {'code': '+378', 'flag': '🇸🇲', 'name': 'سان مارينو'},
    {'code': '+350', 'flag': '🇬🇮', 'name': 'جبل طارق'},
    // ── أمريكا الشمالية والوسطى ────────────────────────────────────────────
    {'code': '+1', 'flag': '🇺🇸', 'name': 'الولايات المتحدة'},
    {'code': '+1', 'flag': '🇨🇦', 'name': 'كندا'},
    {'code': '+52', 'flag': '🇲🇽', 'name': 'المكسيك'},
    {'code': '+502', 'flag': '🇬🇹', 'name': 'غواتيمالا'},
    {'code': '+503', 'flag': '🇸🇻', 'name': 'السلفادور'},
    {'code': '+504', 'flag': '🇭🇳', 'name': 'هندوراس'},
    {'code': '+505', 'flag': '🇳🇮', 'name': 'نيكاراغوا'},
    {'code': '+506', 'flag': '🇨🇷', 'name': 'كوستاريكا'},
    {'code': '+507', 'flag': '🇵🇦', 'name': 'بنما'},
    {'code': '+53', 'flag': '🇨🇺', 'name': 'كوبا'},
    {'code': '+509', 'flag': '🇭🇹', 'name': 'هايتي'},
    {'code': '+1-809', 'flag': '🇩🇴', 'name': 'الدومينيكان'},
    {'code': '+1-876', 'flag': '🇯🇲', 'name': 'جامايكا'},
    {'code': '+1-868', 'flag': '🇹🇹', 'name': 'ترينيداد وتوباغو'},
    {'code': '+1-246', 'flag': '🇧🇧', 'name': 'بربادوس'},
    {'code': '+1-242', 'flag': '🇧🇸', 'name': 'جزر البهاما'},
    // ── أمريكا الجنوبية ────────────────────────────────────────────────────
    {'code': '+55', 'flag': '🇧🇷', 'name': 'البرازيل'},
    {'code': '+54', 'flag': '🇦🇷', 'name': 'الأرجنتين'},
    {'code': '+57', 'flag': '🇨🇴', 'name': 'كولومبيا'},
    {'code': '+56', 'flag': '🇨🇱', 'name': 'تشيلي'},
    {'code': '+51', 'flag': '🇵🇪', 'name': 'بيرو'},
    {'code': '+58', 'flag': '🇻🇪', 'name': 'فنزويلا'},
    {'code': '+593', 'flag': '🇪🇨', 'name': 'الإكوادور'},
    {'code': '+591', 'flag': '🇧🇴', 'name': 'بوليفيا'},
    {'code': '+595', 'flag': '🇵🇾', 'name': 'باراغواي'},
    {'code': '+598', 'flag': '🇺🇾', 'name': 'أوروغواي'},
    {'code': '+592', 'flag': '🇬🇾', 'name': 'غيانا'},
    {'code': '+597', 'flag': '🇸🇷', 'name': 'سورينام'},
    // ── أفريقيا ────────────────────────────────────────────────────────────
    {'code': '+234', 'flag': '🇳🇬', 'name': 'نيجيريا'},
    {'code': '+254', 'flag': '🇰🇪', 'name': 'كينيا'},
    {'code': '+251', 'flag': '🇪🇹', 'name': 'إثيوبيا'},
    {'code': '+233', 'flag': '🇬🇭', 'name': 'غانا'},
    {'code': '+27', 'flag': '🇿🇦', 'name': 'جنوب أفريقيا'},
    {'code': '+255', 'flag': '🇹🇿', 'name': 'تنزانيا'},
    {'code': '+256', 'flag': '🇺🇬', 'name': 'أوغندا'},
    {'code': '+250', 'flag': '🇷🇼', 'name': 'رواندا'},
    {'code': '+257', 'flag': '🇧🇮', 'name': 'بوروندي'},
    {'code': '+258', 'flag': '🇲🇿', 'name': 'موزمبيق'},
    {'code': '+260', 'flag': '🇿🇲', 'name': 'زامبيا'},
    {'code': '+263', 'flag': '🇿🇼', 'name': 'زيمبابوي'},
    {'code': '+265', 'flag': '🇲🇼', 'name': 'ملاوي'},
    {'code': '+266', 'flag': '🇱🇸', 'name': 'ليسوتو'},
    {'code': '+267', 'flag': '🇧🇼', 'name': 'بوتسوانا'},
    {'code': '+268', 'flag': '🇸🇿', 'name': 'إسواتيني'},
    {'code': '+241', 'flag': '🇬🇦', 'name': 'الغابون'},
    {'code': '+237', 'flag': '🇨🇲', 'name': 'الكاميرون'},
    {'code': '+236', 'flag': '🇨🇫', 'name': 'أفريقيا الوسطى'},
    {'code': '+235', 'flag': '🇹🇩', 'name': 'تشاد'},
    {'code': '+243', 'flag': '🇨🇩', 'name': 'الكونغو الديمقراطية'},
    {'code': '+242', 'flag': '🇨🇬', 'name': 'الكونغو'},
    {'code': '+240', 'flag': '🇬🇶', 'name': 'غينيا الاستوائية'},
    {'code': '+245', 'flag': '🇬🇼', 'name': 'غينيا بيساو'},
    {'code': '+224', 'flag': '🇬🇳', 'name': 'غينيا'},
    {'code': '+223', 'flag': '🇲🇱', 'name': 'مالي'},
    {'code': '+226', 'flag': '🇧🇫', 'name': 'بوركينا فاسو'},
    {'code': '+227', 'flag': '🇳🇪', 'name': 'النيجر'},
    {'code': '+225', 'flag': '🇨🇮', 'name': 'ساحل العاج'},
    {'code': '+231', 'flag': '🇱🇷', 'name': 'ليبيريا'},
    {'code': '+232', 'flag': '🇸🇱', 'name': 'سيراليون'},
    {'code': '+220', 'flag': '🇬🇲', 'name': 'غامبيا'},
    {'code': '+221', 'flag': '🇸🇳', 'name': 'السنغال'},
    {'code': '+228', 'flag': '🇹🇬', 'name': 'توغو'},
    {'code': '+229', 'flag': '🇧🇯', 'name': 'بنين'},
    {'code': '+238', 'flag': '🇨🇻', 'name': 'الرأس الأخضر'},
    {'code': '+239', 'flag': '🇸🇹', 'name': 'ساو تومي وبرينسيبي'},
    {'code': '+230', 'flag': '🇲🇺', 'name': 'موريشيوس'},
    {'code': '+261', 'flag': '🇲🇬', 'name': 'مدغشقر'},
    {'code': '+291', 'flag': '🇪🇷', 'name': 'إريتريا'},
    {'code': '+211', 'flag': '🇸🇸', 'name': 'جنوب السودان'},
    {'code': '+244', 'flag': '🇦🇴', 'name': 'أنغولا'},
    {'code': '+264', 'flag': '🇳🇦', 'name': 'ناميبيا'},
    // ── أوقيانوسيا ────────────────────────────────────────────────────────
    {'code': '+61', 'flag': '🇦🇺', 'name': 'أستراليا'},
    {'code': '+64', 'flag': '🇳🇿', 'name': 'نيوزيلندا'},
    {'code': '+679', 'flag': '🇫🇯', 'name': 'فيجي'},
    {'code': '+675', 'flag': '🇵🇬', 'name': 'بابوا غينيا الجديدة'},
    {'code': '+677', 'flag': '🇸🇧', 'name': 'جزر سليمان'},
    {'code': '+678', 'flag': '🇻🇺', 'name': 'فانواتو'},
    {'code': '+685', 'flag': '🇼🇸', 'name': 'ساموا'},
    {'code': '+676', 'flag': '🇹🇴', 'name': 'تونغا'},
    {'code': '+686', 'flag': '🇰🇮', 'name': 'كيريباتي'},
    {'code': '+674', 'flag': '🇳🇷', 'name': 'ناورو'},
    {'code': '+688', 'flag': '🇹🇻', 'name': 'توفالو'},
  ];
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _filtered {
    if (_query.trim().isEmpty) return _CountryPickerSheet.allCountries;
    final q = _query.trim().toLowerCase();
    return _CountryPickerSheet.allCountries.where((c) {
      return c['name']!.contains(q) ||
          c['code']!.contains(q) ||
          c['flag']!.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // ── Handle ─────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          const Text('اختر رمز الدولة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // ── Search ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              textDirection: TextDirection.rtl,
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'ابحث عن دولة أو رمز...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFE91E8C)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // ── List ───────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('لا توجد نتائج لـ "$_query"', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      final isSelected = c['code'] == widget.selectedCode;
                      return ListTile(
                        leading: Text(c['flag']!, style: const TextStyle(fontSize: 26)),
                        title: Text(c['name']!, style: const TextStyle(fontSize: 15)),
                        trailing: Text(
                          c['code']!,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFE91E8C) : Colors.grey.shade600,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFFE91E8C),
                        selectedTileColor: const Color(0xFFE91E8C).withValues(alpha: 0.05),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onSelected(c['code']!, c['flag']!);
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
