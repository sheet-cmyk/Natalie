import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:video_player/video_player.dart';
import '../services/firebase_service.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  // Video
  late VideoPlayerController _videoCtrl;
  bool _videoReady = false;

  // Entrance animation (for login buttons)
  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  bool _loading = false;
  String? _which;

  // هل المستخدم مسجل دخوله مسبقاً؟
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
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    _initVideo();
  }

  Future<void> _initVideo() async {
    _videoCtrl = VideoPlayerController.asset('assets/Video/Video.mp4');
    await _videoCtrl.initialize();
    _videoCtrl.setLooping(false);
    _videoCtrl.setVolume(1.0);
    if (!mounted) return;

    setState(() => _videoReady = true);

    if (_alreadyLoggedIn) {
      // عند انتهاء الفيديو → انتقل تلقائياً
      _videoCtrl.addListener(_onVideoEnd);
    } else {
      // أظهر أزرار الدخول
      _enterCtrl.forward();
    }

    await _videoCtrl.play();
  }

  void _onVideoEnd() {
    final v = _videoCtrl.value;
    if (!v.isPlaying &&
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 200)) {
      _videoCtrl.removeListener(_onVideoEnd);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) _goto(user);
    }
  }

  @override
  void dispose() {
    _videoCtrl.removeListener(_onVideoEnd);
    _videoCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  // ─── Navigation ──────────────────────────────────────────────────────────────

  Future<void> _goto(User user) async {
    if (!mounted) return;
    if (user.isAnonymous) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      return;
    }
    final profile = await FirebaseService().getUser(user.uid);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => (profile == null || !profile.isComplete)
            ? const ProfileScreen()
            : const HomeScreen(),
      ),
    );
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────────

  Future<void> _signInGoogle() async {
    setState(() {
      _loading = true;
      _which = 'google';
    });
    try {
      // signOut أولاً لإجبار Google على عرض قائمة اختيار الحساب
      final gsi = GoogleSignIn();
      await gsi.signOut();
      final g = await gsi.signIn();
      if (g == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final auth = await gsi.currentUser!.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(cred);
      final user = result.user!;

      final blocked = await FirebaseService().isDeviceBlockedForUser(user.uid);
      if (blocked) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'هذا الجهاز مرتبط بحساب آخر — لا يُسمح بأكثر من حساب لكل جهاز'),
              backgroundColor: Color(0xFF7F1D1D),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      await FirebaseService().registerDevice(user.uid);
      await _goto(user);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'فشل تسجيل Google — تأكد من إضافة SHA-1 في Firebase Console'),
            backgroundColor: Color(0xFF7F1D1D),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInGuest() async {
    setState(() {
      _loading = true;
      _which = 'guest';
    });
    try {
      final result = await FirebaseAuth.instance.signInAnonymously();
      await _goto(result.user!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ: $e'),
              backgroundColor: const Color(0xFF7F1D1D)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── خلفية الفيديو ──────────────────────────────────────────
          if (_videoReady)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoCtrl.value.size.width,
                  height: _videoCtrl.value.size.height,
                  child: VideoPlayer(_videoCtrl),
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
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.50),
                  Colors.black.withValues(alpha: 0.75),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── أزرار الدخول (فقط إذا غير مسجل) ──────────────────────
          if (!_alreadyLoggedIn)
            SafeArea(
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideIn,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const Spacer(),
                        _googleButton(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: Divider(
                                    color: Colors.white
                                        .withValues(alpha: 0.25))),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                'أو',
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13),
                              ),
                            ),
                            Expanded(
                                child: Divider(
                                    color: Colors.white
                                        .withValues(alpha: 0.25))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _guestButton(),
                        SizedBox(height: size.height * 0.08),
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

  // ─── Google button ────────────────────────────────────────────────────────────

  Widget _googleButton() {
    final busy = _loading && _which == 'google';
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _loading ? null : _signInGoogle,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          disabledBackgroundColor: Colors.white60,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Color(0xFFE91E8C), strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CustomPaint(painter: _GoogleGPainter()),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'متابعة مع Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── Guest button ─────────────────────────────────────────────────────────────

  Widget _guestButton() {
    final busy = _loading && _which == 'guest';
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
        onPressed: _loading ? null : _signInGuest,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
              color: Colors.white.withValues(alpha: 0.45), width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.white.withValues(alpha: 0.10),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline_rounded,
                      size: 22, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'دخول بدون حساب',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Google G logo ────────────────────────────────────────────────────────────

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;
    final sw = size.width * 0.19;

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;

    p.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi * 0.42, math.pi * 0.65, false, p);

    p.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        math.pi * 0.23, math.pi * 0.72, false, p);

    p.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        math.pi * 0.95, math.pi * 0.28, false, p);

    p.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi * 0.14, math.pi * 0.37, false, p);

    p.color = const Color(0xFF4285F4);
    p.strokeWidth = sw * 0.85;
    canvas.drawLine(Offset(cx, cy), Offset(cx + r, cy), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
