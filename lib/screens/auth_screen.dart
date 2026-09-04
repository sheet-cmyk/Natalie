import 'dart:math';
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
          ? base.substring(0, min(10, base.length))
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
