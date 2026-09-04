import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'admin_screen.dart' show kAdminPin, grantPinAdmin;
import 'home_screen.dart';
import 'phone_auth_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _loading = false;
  String? _generalError;
  late final bool _alreadyLoggedIn;

  @override
  void initState() {
    super.initState();
    _alreadyLoggedIn = FirebaseAuth.instance.currentUser != null;
    if (_alreadyLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goto());
    }
  }

  void _goto() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  // ── Google ────────────────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _generalError = null; });
    try {
      UserCredential cred;
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile')
          ..setCustomParameters({
            'client_id': '1016050589765-jppc1bkb5o9qsq94mgj1q38455agh73p.apps.googleusercontent.com',
            'prompt': 'select_account',
          });
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
      await _ensureUserRecord(cred.user!, displayName: cred.user!.displayName ?? '');
      if (mounted) _goto();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _generalError = e.code == 'popup-closed-by-user'
              ? 'أُغلق النافذة قبل إتمام تسجيل الدخول'
              : e.code == 'popup-blocked'
                  ? 'المتصفح حجب النافذة المنبثقة — أذن بها وأعد المحاولة'
                  : 'فشل تسجيل الدخول بـ Google (${e.code})';
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _generalError = 'فشل تسجيل الدخول بـ Google'; });
    }
  }

  // ── Phone ─────────────────────────────────────────────────────────────────
  void _signInWithPhone() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
    );
  }

  // ── Guest ─────────────────────────────────────────────────────────────────
  Future<void> _signInAsGuest() async {
    setState(() {
      _loading = true;
      _generalError = null;
    });
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      await _ensureUserRecord(cred.user!, isGuest: true);
      if (mounted) _goto();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _generalError = 'فشل الدخول كزائر';
        });
      }
    }
  }

  // ── Admin PIN ─────────────────────────────────────────────────────────────
  Future<void> _showAdminPin() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AuthAdminPinDialog(),
    );
    if (ok != true || !mounted) return;
    setState(() => _loading = true);
    try {
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
            content: Text('خطأ: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Future<void> _ensureUserRecord(
    User user, {
    String displayName = '',
    bool isGuest = false,
  }) async {
    final db = FirebaseFirestore.instance;
    final doc = await db.collection('users').doc(user.uid).get();
    if (doc.exists &&
        (doc.data()?['username'] as String?)?.isNotEmpty == true) {
      return;
    }

    String id;
    if (isGuest) {
      id = 'guest_${user.uid.substring(0, 6)}';
    } else if (displayName.isNotEmpty) {
      final base =
          displayName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
      id = base.length >= 4
          ? base.substring(0, math.min(10, base.length))
          : user.uid.substring(0, 8);
    } else {
      id = 'user${user.uid.substring(0, 8)}';
    }
    await _initNewUser(user.uid, id);
  }

  Future<void> _initNewUser(String uid, String id) async {
    final db = FirebaseFirestore.instance;
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
        'photoUrls': [],
        'published': false,
        'blocked': false,
        'pendingPublish': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(db.collection('usernames').doc(id.toLowerCase()), {
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background image ───────────────────────────────────────────
          Image.asset('assets/Image/MSA1.png', fit: BoxFit.cover),

          // ── Butterfly animation ────────────────────────────────────────
          const Positioned.fill(child: _ButterflyAnimation()),

          // ── Bottom buttons ─────────────────────────────────────────────
          if (!_alreadyLoggedIn)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildButtons(),
            ),

          // ── Loading overlay ────────────────────────────────────────────
          if (_loading) ...[
            Container(color: Colors.black.withValues(alpha: 0.40)),
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE91E8C),
                strokeWidth: 3,
              ),
            ),
          ],

          // ── Error banner ───────────────────────────────────────────────
          if (_generalError != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade800.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _generalError!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _generalError = null),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Admin PIN button ───────────────────────────────────────────
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
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
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

  Widget _buildButtons() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Google ─────────────────────────────────────────────────
            _AuthActionButton(
              onTap: _loading ? null : _signInWithGoogle,
              backgroundColor: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _GoogleIcon(size: 24),
                  SizedBox(width: 10),
                  Text(
                    'تسجيل الدخول باستخدام جوجل',
                    style: TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Phone ──────────────────────────────────────────────────
            _AuthActionButton(
              onTap: _loading ? null : _signInWithPhone,
              backgroundColor: Colors.white,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone_android_rounded,
                    color: Color(0xFF2196F3),
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'تسجيل الدخول برقم الهاتف',
                    style: TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Guest ──────────────────────────────────────────────────
            _AuthActionButton(
              onTap: _loading ? null : _signInAsGuest,
              backgroundColor: const Color(0xFF5CB85C),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'الدخول كزائر',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Auth action button ───────────────────────────────────────────────────────

class _AuthActionButton extends StatelessWidget {
  const _AuthActionButton({
    required this.onTap,
    required this.backgroundColor,
    required this.child,
  });

  final VoidCallback? onTap;
  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: Center(child: child),
        ),
      ),
    );
  }
}

// ─── Google G icon ────────────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon({this.size = 24.0});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  static double _r(double deg) => deg * 3.14159265358979 / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final cy = s / 2;
    final radius = s * 0.44;
    final sw = s * 0.17;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    // Blue  — 347° → 107° clockwise (120°)
    p.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, _r(347), _r(120), false, p);

    // Red   — 107° → 222° (115°)
    p.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, _r(107), _r(115), false, p);

    // Yellow — 222° → 290° (68°)
    p.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, _r(222), _r(68), false, p);

    // Green — 290° → 347° (57°)
    p.color = const Color(0xFF34A853);
    canvas.drawArc(rect, _r(290), _r(57), false, p);

    // Blue horizontal bar (center-right)
    p.color = const Color(0xFF4285F4);
    p.strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + radius + sw / 2, cy),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
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
    if (pin.isEmpty) {
      setState(() => _error = 'أدخل الرقم السري');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    if (pin == kAdminPin) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _loading = false;
        _error = 'الرقم السري غير صحيح';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFE91E8C)),
          SizedBox(width: 8),
          Text(
            'دخول الأدمن',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinCtrl,
            obscureText: true,
            textDirection: TextDirection.ltr,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'الرقم السري',
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: Color(0xFFE91E8C),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE91E8C),
                  width: 2,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE91E8C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('دخول'),
        ),
      ],
    );
  }
}

// ─── Butterfly Animation ──────────────────────────────────────────────────────

class _ButterflyAnimation extends StatefulWidget {
  const _ButterflyAnimation();

  @override
  State<_ButterflyAnimation> createState() => _ButterflyAnimationState();
}

class _ButterflyAnimationState extends State<_ButterflyAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _pathCtrl;
  late final AnimationController _wingCtrl;
  late final AnimationController _tickCtrl;

  final List<_Sparkle> _sparkles = [];
  final math.Random _rng = math.Random();
  int _frame = 0;

  // Previous position — used to compute heading angle
  Offset _prevPos = Offset.zero;
  double _heading = 0;

  @override
  void initState() {
    super.initState();

    // One full loop of the flight path: 28 seconds (very slow)
    _pathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();

    // Wing flap: one stroke every ~220 ms
    _wingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..repeat(reverse: true);

    // 60 fps tick for particles
    _tickCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();

    _tickCtrl.addListener(_onTick);
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    _wingCtrl.dispose();
    _tickCtrl.dispose();
    super.dispose();
  }

  // ── Flight path (Lissajous-inspired) ─────────────────────────────────────
  Offset _position(Size sz) {
    final t = _pathCtrl.value * 2 * math.pi;
    // Two independent sine frequencies → natural wandering figure-eight
    final x = sz.width  * 0.50 + sz.width  * 0.38 * math.sin(t * 0.83 + 0.9);
    final y = sz.height * 0.38 + sz.height * 0.28 * math.sin(t * 0.57);
    return Offset(x, y);
  }

  void _onTick() {
    _frame++;
    final sz = _getSize();
    if (sz == Size.zero) return;

    final pos = _position(sz);

    // Heading from prev → current position
    final delta = pos - _prevPos;
    if (delta.distance > 0.1) {
      _heading = math.atan2(delta.dy, delta.dx);
    }
    _prevPos = pos;

    // Spawn a sparkle every 3 frames
    if (_frame % 3 == 0 && _sparkles.length < 40) {
      _sparkles.add(_Sparkle(
        x: pos.dx + (_rng.nextDouble() - 0.5) * 30,
        y: pos.dy + (_rng.nextDouble() - 0.5) * 30,
        vx: (_rng.nextDouble() - 0.5) * 0.7,
        vy: -(_rng.nextDouble() * 0.9 + 0.3),
        size: _rng.nextDouble() * 5 + 3,
        rot: _rng.nextDouble() * math.pi,
        life: 0,
        maxLife: 55 + _rng.nextInt(35),
        // alternate gold and white sparkles
        gold: _rng.nextBool(),
      ));
    }

    // Age and remove dead sparkles
    for (final s in _sparkles) {
      s.x  += s.vx;
      s.y  += s.vy;
      s.rot += 0.04;
      s.life++;
    }
    _sparkles.removeWhere((s) => s.life >= s.maxLife);

    setState(() {});
  }

  Size _getSize() {
    final ctx = context;
    if (!ctx.mounted) return Size.zero;
    final rb = ctx.findRenderObject();
    if (rb is RenderBox && rb.hasSize) return rb.size;
    return Size.zero;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final sz = Size(constraints.maxWidth, constraints.maxHeight);
        final pos = _position(sz);

        // Wing flap: scaleX oscillates 0.18 → 1.0 → 0.18
        final flapT = _wingCtrl.value;
        // ease in-out gives the "snap" of real wings
        final scaleX = 0.18 + 0.82 * math.pow(math.sin(flapT * math.pi), 0.6);

        return Stack(
          children: [
            // ── Sparkles / stars ──────────────────────────────────────
            CustomPaint(
              size: sz,
              painter: _SparklePainter(_sparkles),
            ),

            // ── Butterfly ─────────────────────────────────────────────
            Positioned(
              left: pos.dx - 45,
              top:  pos.dy - 45,
              child: Transform.rotate(
                angle: _heading + math.pi / 2,
                child: Transform.scale(
                  scaleX: scaleX.toDouble(),
                  child: Image.asset(
                    'assets/Image/4.png',
                    width: 90,
                    height: 90,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Sparkle data ─────────────────────────────────────────────────────────────

class _Sparkle {
  double x, y, vx, vy, size, rot;
  int life, maxLife;
  bool gold;

  _Sparkle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.size, required this.rot,
    required this.life, required this.maxLife,
    required this.gold,
  });

  double get opacity {
    final ratio = life / maxLife;
    // fade in quickly, fade out slowly
    if (ratio < 0.15) return ratio / 0.15;
    return 1.0 - ((ratio - 0.15) / 0.85);
  }
}

// ─── Sparkle painter ─────────────────────────────────────────────────────────

class _SparklePainter extends CustomPainter {
  final List<_Sparkle> sparkles;
  _SparklePainter(this.sparkles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in sparkles) {
      final op = s.opacity.clamp(0.0, 1.0);
      if (op <= 0) continue;

      canvas.save();
      canvas.translate(s.x, s.y);
      canvas.rotate(s.rot);

      // Outer glow
      final glowPaint = Paint()
        ..color = (s.gold ? const Color(0xFFFFD770) : Colors.white)
            .withValues(alpha: op * 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset.zero, s.size * 1.6, glowPaint);

      // 4-pointed star
      final starPaint = Paint()
        ..color = (s.gold ? const Color(0xFFFFCC44) : Colors.white)
            .withValues(alpha: op)
        ..style = PaintingStyle.fill;
      canvas.drawPath(_star4(s.size), starPaint);

      // Tiny bright center
      final centerPaint = Paint()
        ..color = Colors.white.withValues(alpha: op * 0.95);
      canvas.drawCircle(Offset.zero, s.size * 0.25, centerPaint);

      canvas.restore();
    }
  }

  // 4-pointed diamond star
  Path _star4(double r) {
    const inner = 0.28;
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - math.pi / 2;
      final rad   = i.isEven ? r : r * inner;
      final pt    = Offset(math.cos(angle) * rad, math.sin(angle) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => true;
}
