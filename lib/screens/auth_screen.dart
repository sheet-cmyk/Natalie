import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'admin_screen.dart' show kAdminPin, grantPinAdmin;
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  // Video
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

  // Entrance animation
  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  final _idCtrl = TextEditingController();
  bool _loading = false;
  String? _idError;
  XFile? _avatarFile;
  Uint8List? _avatarBytes;

  late final bool _alreadyLoggedIn;

  @override
  void initState() {
    super.initState();
    _alreadyLoggedIn = FirebaseAuth.instance.currentUser != null;

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final ctrl = VideoPlayerController.asset('assets/Video/Video.mp4');
      _videoCtrl = ctrl;
      await ctrl.initialize();
      ctrl.setLooping(false);
      ctrl.setVolume(kIsWeb ? 0.0 : 1.0);
      if (!mounted) return;

      setState(() => _videoReady = true);

      if (_alreadyLoggedIn) {
        ctrl.addListener(_onVideoEnd);
      } else {
        _enterCtrl.forward();
      }

      await ctrl.play();
    } catch (_) {
      // If video fails (e.g. web autoplay blocked), fall through gracefully
      if (!mounted) return;
      if (_alreadyLoggedIn) {
        _goto();
      } else {
        _enterCtrl.forward();
      }
    }
  }

  void _onVideoEnd() {
    final ctrl = _videoCtrl;
    if (ctrl == null) return;
    final v = ctrl.value;
    if (!v.isPlaying &&
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 200)) {
      ctrl.removeListener(_onVideoEnd);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) _goto();
    }
  }

  @override
  void dispose() {
    _videoCtrl?.removeListener(_onVideoEnd);
    _videoCtrl?.dispose();
    _enterCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    _enterCtrl.stop();
    super.deactivate();
  }

  void _goto() {
    if (!mounted) return;
    _enterCtrl.stop();
    _videoCtrl?.removeListener(_onVideoEnd);
    _videoCtrl?.pause();
    // Remove VideoPlayer from tree before navigation to avoid async events during deactivation
    setState(() { _videoReady = false; });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    });
  }

  Future<void> _showAdminPin() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AuthAdminPinDialog(),
    );
    if (ok == true && mounted) {
      setState(() => _loading = true);
      try {
        if (FirebaseAuth.instance.currentUser == null) {
          await FirebaseAuth.instance.signInAnonymously();
        }
        // Re-grant after sign-in so admin_sessions/{uid} is written with correct UID
        await grantPinAdmin();
        if (mounted) _goto();
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _enterAsGuest() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
      if (mounted) _goto();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _idError = 'خطأ: $e'; });
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() { _avatarFile = picked; _avatarBytes = bytes; });
    }
  }

  String _deriveEmail(String id) =>
      '${id.toLowerCase().trim()}@om-natalie.app';
  String _derivePassword(String id) => 'om${id.trim()}natalie2024!';

  Future<void> _signIn() async {
    final id = _idCtrl.text.trim();

    if (id.isEmpty) {
      setState(() => _idError = 'أدخل الـ ID');
      return;
    }
    if (id.length < 4) {
      setState(() => _idError = 'الـ ID يجب أن يكون 4 أحرف/أرقام على الأقل');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(id)) {
      setState(() => _idError = 'حروف إنجليزية وأرقام فقط');
      return;
    }

    setState(() {
      _loading = true;
      _idError = null;
    });
    try {
      final email = _deriveEmail(id);
      final password = _derivePassword(id);

      UserCredential cred;
      bool didInit = false;
      try {
        cred = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          cred = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(email: email, password: password);
          await _initNewUser(cred.user!.uid, id, avatarFile: _avatarFile);
          didInit = true;
        } else {
          rethrow;
        }
      }

      // For returning users: ensure Firestore document exists
      if (!didInit) {
        try {
          final uid = cred.user!.uid;
          final doc = await FirebaseFirestore.instance
              .collection('users').doc(uid).get();
          if (!doc.exists || doc.data()?['username'] == null) {
            await _initNewUser(uid, id);
          }
        } catch (_) {}
      }

      if (!mounted) return;
      _goto();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _idError = _authErrorMsg(e.code);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _idError = 'خطأ: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _initNewUser(String uid, String id,
      {XFile? avatarFile}) async {
    final db = FirebaseFirestore.instance;

    // رفع الصورة إن وُجدت
    String avatarUrl = '';
    if (avatarFile != null) {
      try {
        final bytes = await avatarFile.readAsBytes();
        final ts = DateTime.now().millisecondsSinceEpoch;
        final ref = FirebaseStorage.instance
            .ref('users/$uid/photo_0_$ts.jpg');
        final task = await ref.putData(
            bytes, SettableMetadata(contentType: 'image/jpeg'));
        avatarUrl = await task.ref.getDownloadURL();
      } catch (_) {
        avatarUrl = '';
      }
    }

    final batch = db.batch();

    batch.set(
      db.collection('users').doc(uid),
      {
        'email': '',
        'name': '',
        'username': id,
        'age': 0,
        'bio': '',
        'whatsapp': '',
        'facebook': '',
        'tiktok': '',
        'instagram': '',
        'photoUrls': avatarUrl.isNotEmpty ? [avatarUrl] : [],
        'published': false,
        'blocked': false,
        'pendingPublish': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      db.collection('usernames').doc(id.toLowerCase()),
      {'uid': uid, 'createdAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();
  }

  String _authErrorMsg(String code) {
    switch (code) {
      case 'wrong-password':
        return 'هذا الـ ID مسجل بحساب آخر';
      case 'too-many-requests':
        return 'محاولات كثيرة، انتظر قليلاً';
      case 'network-request-failed':
        return 'تحقق من الاتصال بالإنترنت';
      default:
        return 'خطأ في تسجيل الدخول ($code)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── خلفية الفيديو ──────────────────────────────────────────
          if (_videoReady && _videoCtrl != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoCtrl!.value.size.width,
                  height: _videoCtrl!.value.size.height,
                  child: VideoPlayer(_videoCtrl!),
                ),
              ),
            )
          else
            const ColoredBox(color: Colors.black),

          // ── طبقة تعتيم ─────────────────────────────────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.20),
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.80),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── أيقونة الأدمن الخفية (أعلى اليمين) ────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, top: 6),
                child: GestureDetector(
                  onTap: _showAdminPin,
                  child: Opacity(
                    opacity: 0.18,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE91E8C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: Colors.white, size: 15),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── واجهة الدخول ───────────────────────────────────────────
          if (!_alreadyLoggedIn)
            SafeArea(
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideIn,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const Spacer(),
                        _buildLoginCard(size),
                        SizedBox(height: size.height * 0.06),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(Size size) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: const Color(0xFFE91E8C).withValues(alpha: 0.4),
            width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E8C).withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── صورة الملف الشخصي ──────────────────────────────────────
          GestureDetector(
            onTap: _loading ? null : _pickAvatar,
            child: Stack(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFE91E8C), width: 2.5),
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  child: ClipOval(
                    child: _avatarBytes != null
                        ? Image.memory(
                            _avatarBytes!,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.person_rounded,
                            color: Color(0xFFE91E8C), size: 42),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E8C),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Text(
            'اختر صورة (اختياري)',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11),
          ),

          const SizedBox(height: 16),

          // ── عنوان ──────────────────────────────────────────────────
          const Text(
            'مرحباً بك',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'أدخل الـ ID الخاص بك للدخول أو إنشاء حساب',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 12),
          ),
          const SizedBox(height: 18),

          // ── حقل الـ ID ─────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _idError != null
                    ? Colors.red
                    : const Color(0xFFE91E8C).withValues(alpha: 0.6),
                width: 1.4,
              ),
            ),
            child: TextField(
              controller: _idCtrl,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              maxLength: 10,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9]')),
              ],
              decoration: InputDecoration(
                counterText: '',
                hintText: 'ID (4-10)',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 16,
                    letterSpacing: 1,
                    fontWeight: FontWeight.normal),
                prefixIcon: const Icon(Icons.tag_rounded,
                    color: Color(0xFFE91E8C), size: 22),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
              ),
              onChanged: (_) {
                if (_idError != null) setState(() => _idError = null);
              },
              onSubmitted: (_) => _signIn(),
            ),
          ),

          // ── رسالة الخطأ ────────────────────────────────────────────
          if (_idError != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_idError!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          // ── تلميح ──────────────────────────────────────────────────
          Text(
            'حساب موجود؟ أدخل نفس الـ ID\nجديد؟ اختر ID فريد (4-10 خانات)',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                height: 1.5),
          ),

          const SizedBox(height: 16),

          // ── زر الدخول ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E8C),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFFE91E8C).withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_rounded,
                            size: 22, color: Colors.white),
                        SizedBox(width: 10),
                        Text(
                          'دخول',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 10),

          // ── زر الزائر ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _enterAsGuest,
              icon: Icon(Icons.visibility_outlined,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.65)),
              label: Text('تصفح كزائر',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.25), width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Admin PIN dialog (auth screen) ──────────────────────────────────────────

class _AuthAdminPinDialog extends StatefulWidget {
  const _AuthAdminPinDialog();

  @override
  State<_AuthAdminPinDialog> createState() => _AuthAdminPinDialogState();
}

class _AuthAdminPinDialogState extends State<_AuthAdminPinDialog> {
  final _pinCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) { setState(() => _error = 'أدخل الرقم السري'); return; }
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    if (pin == kAdminPin) {
      await grantPinAdmin();
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() { _loading = false; _error = 'الرقم السري غير صحيح'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFE91E8C)),
        SizedBox(width: 8),
        Text('دخول الأدمن',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _pinCtrl,
          obscureText: true,
          textDirection: TextDirection.ltr,
          autofocus: true,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'الرقم السري',
            prefixIcon:
                const Icon(Icons.lock_outline, color: Color(0xFFE91E8C)),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFFE91E8C), width: 2),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ]),
      actions: [
        TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context, false),
            child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE91E8C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('دخول'),
        ),
      ],
    );
  }
}
