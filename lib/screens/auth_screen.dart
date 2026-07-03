import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
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

  bool _loading = false;

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
    final ctrl = VideoPlayerController.asset('assets/Video/Video.mp4');
    _videoCtrl = ctrl;
    await ctrl.initialize();
    ctrl.setLooping(false);
    // Browsers block autoplay with audio — mute on web so video plays
    ctrl.setVolume(kIsWeb ? 0.0 : 1.0);
    if (!mounted) return;

    setState(() => _videoReady = true);

    if (_alreadyLoggedIn) {
      ctrl.addListener(_onVideoEnd);
    } else {
      _enterCtrl.forward();
    }

    await ctrl.play();
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
      if (user != null && mounted) _goto(user);
    }
  }

  @override
  void dispose() {
    _videoCtrl?.removeListener(_onVideoEnd);
    _videoCtrl?.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _goto(User user) async {
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  Future<void> _signInGuest() async {
    setState(() => _loading = true);
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
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.50),
                  Colors.black.withValues(alpha: 0.75),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── زر الدخول (فقط إذا غير مسجل) ─────────────────────────
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

  Widget _guestButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _loading ? null : _signInGuest,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE91E8C),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE91E8C).withValues(alpha: 0.5),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                  Icon(Icons.arrow_forward_rounded, size: 22, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'دخول',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
