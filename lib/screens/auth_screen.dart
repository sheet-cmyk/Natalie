import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  // ── Video ─────────────────────────────────────────────────────────────────
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

  // ── Entrance animation ────────────────────────────────────────────────────
  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  // ── Mode ──────────────────────────────────────────────────────────────────
  bool _isLogin = true;
  bool _passVisible = false;
  bool _confirmVisible = false;

  // ── Controllers ───────────────────────────────────────────────────────────
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _loading = false;
  String? _idError;
  String? _passError;
  String? _confirmError;
  String? _generalError;
  XFile? _avatarFile;
  Uint8List? _avatarBytes;

  late final bool _alreadyLoggedIn;

  @override
  void initState() {
    super.initState();
    _alreadyLoggedIn = FirebaseAuth.instance.currentUser != null;

    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeIn = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
            begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
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
      if (FirebaseAuth.instance.currentUser != null && mounted) _goto();
    }
  }

  @override
  void dispose() {
    _videoCtrl?.removeListener(_onVideoEnd);
    _videoCtrl?.dispose();
    _enterCtrl.dispose();
    _idCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
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
    setState(() => _videoReady = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    });
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _idError = null;
      _passError = null;
      _confirmError = null;
      _generalError = null;
      _passCtrl.clear();
      _confirmCtrl.clear();
      _passVisible = false;
      _confirmVisible = false;
    });
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() { _avatarFile = picked; _avatarBytes = bytes; });
    }
  }

  String _emailFromId(String id) =>
      '${id.toLowerCase().trim()}@om-natalie.app';

  bool _validateLogin() {
    final id = _idCtrl.text.trim();
    bool ok = true;
    if (id.length < 4) {
      _idError = 'الـ ID 4 أحرف/أرقام على الأقل';
      ok = false;
    } else if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(id)) {
      _idError = 'حروف إنجليزية وأرقام فقط';
      ok = false;
    }
    if (_passCtrl.text.isEmpty) {
      _passError = 'أدخل كلمة المرور';
      ok = false;
    }
    return ok;
  }

  bool _validateRegister() {
    final id = _idCtrl.text.trim();
    bool ok = true;
    if (id.length < 4) {
      _idError = 'الـ ID 4 أحرف/أرقام على الأقل';
      ok = false;
    } else if (id.length > 10) {
      _idError = 'الـ ID 10 خانات كحد أقصى';
      ok = false;
    } else if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(id)) {
      _idError = 'حروف إنجليزية وأرقام فقط';
      ok = false;
    }
    if (_passCtrl.text.length < 6) {
      _passError = 'كلمة المرور 6 أحرف على الأقل';
      ok = false;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      _confirmError = 'كلمتا المرور غير متطابقتين';
      ok = false;
    }
    return ok;
  }

  Future<void> _signIn() async {
    setState(() {
      _idError = null; _passError = null;
      _confirmError = null; _generalError = null;
    });
    if (!_validateLogin()) { setState(() {}); return; }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailFromId(_idCtrl.text.trim()),
        password: _passCtrl.text,
      );
      if (mounted) _goto();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { _loading = false; _generalError = _authErrorMsg(e.code); });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _generalError = 'خطأ: $e'; });
    }
  }

  Future<void> _register() async {
    setState(() {
      _idError = null; _passError = null;
      _confirmError = null; _generalError = null;
    });
    if (!_validateRegister()) { setState(() {}); return; }
    setState(() => _loading = true);
    try {
      final id = _idCtrl.text.trim();
      final snap = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(id.toLowerCase())
          .get();
      if (snap.exists) {
        if (mounted) setState(() { _loading = false; _idError = 'هذا الـ ID مستخدم بالفعل'; });
        return;
      }
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailFromId(id),
        password: _passCtrl.text,
      );
      await _initNewUser(cred.user!.uid, id, avatarFile: _avatarFile);
      if (mounted) _goto();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { _loading = false; _generalError = _authErrorMsg(e.code); });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _generalError = 'خطأ: $e'; });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _generalError = null; });
    try {
      UserCredential cred;
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        cred = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        cred = await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          ),
        );
      }
      final uid = cred.user!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      if (!doc.exists || doc.data()?['username'] == null) {
        final autoId = _autoIdFromGoogle(
            cred.user!.displayName ?? '', uid);
        await _initNewUser(uid, autoId);
      }
      if (mounted) _goto();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _generalError = 'خطأ في Google: $e'; });
    }
  }

  String _autoIdFromGoogle(String displayName, String uid) {
    final base = displayName
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toLowerCase();
    if (base.length >= 4) return base.substring(0, min(10, base.length));
    return uid.substring(0, 8);
  }

  Future<void> _initNewUser(String uid, String id,
      {XFile? avatarFile}) async {
    final db = FirebaseFirestore.instance;
    String avatarUrl = '';
    if (avatarFile != null) {
      try {
        final bytes = await avatarFile.readAsBytes();
        final ts = DateTime.now().millisecondsSinceEpoch;
        final ref = FirebaseStorage.instance.ref('users/$uid/photo_0_$ts.jpg');
        final task = await ref.putData(
            bytes, SettableMetadata(contentType: 'image/jpeg'));
        avatarUrl = await task.ref.getDownloadURL();
      } catch (_) {}
    }
    final batch = db.batch();
    batch.set(db.collection('users').doc(uid), {
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
    }, SetOptions(merge: true));
    batch.set(db.collection('usernames').doc(id.toLowerCase()),
        {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  String _authErrorMsg(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'الـ ID أو كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'هذا الـ ID مستخدم بالفعل';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً (6 أحرف على الأقل)';
      case 'too-many-requests':
        return 'محاولات كثيرة، انتظر قليلاً';
      case 'network-request-failed':
        return 'تحقق من الاتصال بالإنترنت';
      default:
        return 'خطأ ($code)';
    }
  }

  // ── Admin PIN ──────────────────────────────────────────────────────────────
  Future<void> _showAdminPin() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AuthAdminPinDialog(),
    );
    if (ok != true || !mounted) return;
    setState(() => _loading = true);
    try {
      // Sign in anonymously only if not already signed in
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      await grantPinAdmin();
      if (mounted) _goto();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تسجيل دخول الأدمن: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video background ───────────────────────────────────────────
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

          // ── Gradient overlay ───────────────────────────────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.50),
                  Colors.black.withValues(alpha: 0.90),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // ── Form ───────────────────────────────────────────────────────
          if (!_alreadyLoggedIn)
            SafeArea(
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideIn,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        28, size.height * 0.12, 28, 28),
                    child: _buildCard(),
                  ),
                ),
              ),
            ),

          // ── Admin button — LAST in stack so it's always on top ─────────
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 8),
                child: GestureDetector(
                  onTap: _loading ? null : _showAdminPin,
                  behavior: HitTestBehavior.opaque,
                  child: Opacity(
                    opacity: 0.30,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE91E8C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
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

            // ── Avatar (register only) ──────────────────────────────────
            if (!_isLogin) ...[
              GestureDetector(
                onTap: _loading ? null : _pickAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFE91E8C), width: 2.5),
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: ClipOval(
                        child: _avatarBytes != null
                            ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                            : const Icon(Icons.person_rounded,
                                color: Color(0xFFE91E8C), size: 42),
                      ),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 26, height: 26,
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
              Text('صورة الملف الشخصي (اختياري)',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11)),
              const SizedBox(height: 14),
            ],

            // ── Title ───────────────────────────────────────────────────
            Text(
              _isLogin ? 'تسجيل الدخول' : 'إنشاء حساب',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),

            // ── ID field ────────────────────────────────────────────────
            _Field(
              ctrl: _idCtrl,
              hint: 'ID  (مثال: ali123)',
              icon: Icons.tag_rounded,
              error: _idError,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'))
              ],
              maxLength: 10,
              textDirection: TextDirection.ltr,
              onChanged: (_) => setState(() => _idError = null),
            ),
            const SizedBox(height: 10),

            // ── Password field ──────────────────────────────────────────
            _Field(
              ctrl: _passCtrl,
              hint: 'كلمة المرور',
              icon: Icons.lock_outline_rounded,
              error: _passError,
              obscure: !_passVisible,
              suffixIcon: IconButton(
                icon: Icon(
                    _passVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white38, size: 20),
                onPressed: () => setState(() => _passVisible = !_passVisible),
              ),
              onChanged: (_) => setState(() => _passError = null),
              onSubmitted: _isLogin ? (_) => _signIn() : null,
            ),
            const SizedBox(height: 10),

            // ── Confirm password (register only) ────────────────────────
            if (!_isLogin) ...[
              _Field(
                ctrl: _confirmCtrl,
                hint: 'تأكيد كلمة المرور',
                icon: Icons.lock_outline_rounded,
                error: _confirmError,
                obscure: !_confirmVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                      _confirmVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white38, size: 20),
                  onPressed: () =>
                      setState(() => _confirmVisible = !_confirmVisible),
                ),
                onChanged: (_) => setState(() => _confirmError = null),
                onSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 10),
            ],

            // ── General error ────────────────────────────────────────────
            if (_generalError != null) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_generalError!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
                ),
              ]),
            ],

            const SizedBox(height: 16),

            // ── Main action button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : (_isLogin ? _signIn : _register),
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
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                              _isLogin
                                  ? Icons.login_rounded
                                  : Icons.person_add_rounded,
                              size: 22, color: Colors.white),
                          const SizedBox(width: 10),
                          Text(
                            _isLogin ? 'دخول' : 'إنشاء الحساب',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Divider ─────────────────────────────────────────────────
            Row(children: [
              Expanded(
                  child: Divider(
                      color: Colors.white.withValues(alpha: 0.2),
                      thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('أو',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 13)),
              ),
              Expanded(
                  child: Divider(
                      color: Colors.white.withValues(alpha: 0.2),
                      thickness: 1)),
            ]),

            const SizedBox(height: 14),

            // ── Google Sign-In button ────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _loading ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      width: 22,
                      height: 22,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.g_mobiledata_rounded,
                          color: Colors.white70,
                          size: 26),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'تسجيل الدخول بـ Google',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Toggle login / register ──────────────────────────────────
            GestureDetector(
              onTap: _loading ? null : _toggleMode,
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13),
                  children: [
                    TextSpan(
                        text: _isLogin
                            ? 'ليس لديك حساب؟  '
                            : 'لديك حساب؟  '),
                    TextSpan(
                      text: _isLogin ? 'إنشاء حساب' : 'تسجيل الدخول',
                      style: const TextStyle(
                          color: Color(0xFFE91E8C),
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable field ───────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.hint,
    required this.icon,
    this.error,
    this.obscure = false,
    this.suffixIcon,
    this.inputFormatters,
    this.maxLength,
    this.textDirection,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final String? error;
  final bool obscure;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final TextDirection? textDirection;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: error != null
                  ? Colors.redAccent
                  : const Color(0xFFE91E8C).withValues(alpha: 0.6),
              width: 1.4,
            ),
          ),
          child: TextField(
            controller: ctrl,
            obscureText: obscure,
            textDirection: textDirection,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              counterText: '',
              hintText: hint,
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
              prefixIcon:
                  Icon(icon, color: const Color(0xFFE91E8C), size: 22),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 13),
              const SizedBox(width: 4),
              Expanded(
                child: Text(error!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 11)),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

// ─── Admin PIN dialog ─────────────────────────────────────────────────────────

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
            onPressed: _loading
                ? null
                : () => Navigator.pop(context, false),
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
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('دخول'),
        ),
      ],
    );
  }
}
