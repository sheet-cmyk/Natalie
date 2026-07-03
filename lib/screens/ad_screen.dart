import 'dart:io' show File;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import '../models/ad_model.dart';
import '../services/firebase_service.dart';
import 'home_screen.dart';

class AdScreen extends StatefulWidget {
  const AdScreen({super.key});

  @override
  State<AdScreen> createState() => _AdScreenState();
}

class _AdScreenState extends State<AdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();

  final List<XFile?> _localPhotos = List.filled(5, null);
  final List<String> _existingUrls = List.filled(5, '');
  bool _saving = false;
  bool _initialLoading = true;
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _bioCtrl.dispose();
    _whatsappCtrl.dispose();
    _facebookCtrl.dispose();
    _tiktokCtrl.dispose();
    _instagramCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAd() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      setState(() => _initialLoading = false);
      return;
    }
    _isAnonymous = authUser.isAnonymous;
    try {
      // Try existing ad first
      final ad = await FirebaseService().getAd(authUser.uid);
      if (mounted && ad != null) {
        setState(() {
          _nameCtrl.text = ad.name;
          _ageCtrl.text = ad.age > 0 ? ad.age.toString() : '';
          _bioCtrl.text = ad.bio;
          _whatsappCtrl.text = ad.whatsapp;
          _facebookCtrl.text = ad.facebook;
          _tiktokCtrl.text = ad.tiktok;
          _instagramCtrl.text = ad.instagram;
          for (int i = 0; i < ad.photoUrls.length && i < 5; i++) {
            _existingUrls[i] = ad.photoUrls[i];
          }
        });
        return;
      }
      // No ad yet — pre-fill from profile
      final profile = await FirebaseService().getUser(authUser.uid);
      if (mounted && profile != null) {
        setState(() {
          _nameCtrl.text = profile.name;
          _ageCtrl.text = profile.age > 0 ? profile.age.toString() : '';
          _bioCtrl.text = profile.bio;
          _whatsappCtrl.text = profile.whatsapp;
          _facebookCtrl.text = profile.facebook;
          _tiktokCtrl.text = profile.tiktok;
          _instagramCtrl.text = profile.instagram;
          for (int i = 0; i < profile.photoUrls.length && i < 5; i++) {
            _existingUrls[i] = profile.photoUrls[i];
          }
        });
      } else if (mounted &&
          authUser.displayName != null &&
          authUser.displayName!.isNotEmpty) {
        setState(() => _nameCtrl.text = authUser.displayName!);
      }
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _pickPhoto(int index) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _localPhotos[index] = picked);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _localPhotos[index] = null;
      _existingUrls[index] = '';
    });
  }

  Future<void> _showLoginSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GoogleLoginSheet(),
    );
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous && mounted) {
      setState(() => _isAnonymous = false);
      await _save();
    }
  }

  Future<void> _save() async {
    if (_isAnonymous || FirebaseAuth.instance.currentUser == null) {
      await _showLoginSheet();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final hasPhoto = _localPhotos.any((f) => f != null) ||
        _existingUrls.any((u) => u.isNotEmpty);
    if (!hasPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة صورة واحدة على الأقل'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final service = FirebaseService();
      final List<String> finalUrls = List.filled(5, '');

      for (int i = 0; i < 5; i++) {
        if (_localPhotos[i] != null) {
          finalUrls[i] = await service.uploadAdPhoto(uid, _localPhotos[i]!, i);
        } else {
          finalUrls[i] = _existingUrls[i];
        }
      }

      final photoUrls = finalUrls.where((u) => u.isNotEmpty).toList();
      final name = _nameCtrl.text.trim();
      final age = int.tryParse(_ageCtrl.text.trim()) ?? 0;
      final bio = _bioCtrl.text.trim();

      final ad = AdModel(
        uid: uid,
        name: name,
        age: age,
        bio: bio,
        whatsapp: _whatsappCtrl.text.trim(),
        facebook: _facebookCtrl.text.trim(),
        tiktok: _tiktokCtrl.text.trim(),
        instagram: _instagramCtrl.text.trim(),
        photoUrls: photoUrls,
        published: name.isNotEmpty && age > 0 && bio.isNotEmpty && photoUrls.isNotEmpty,
      );

      await service.saveAd(ad);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نشر الإعلان بنجاح ✓'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      if (ad.published) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _inputDeco(String label, IconData? icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFFE91E8C))));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('إعلاني',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFFE91E8C),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('نشر',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ],
      ),
      body: _saving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFE91E8C)),
                  SizedBox(height: 16),
                  Text('جاري رفع الصور والنشر...',
                      style: TextStyle(fontSize: 15)),
                ],
              ),
            )
          : Column(
              children: [
                      Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ─── Photos ───
                        _SectionCard(
                          title: 'الصور (حد أقصى 5 صور)',
                          child: SizedBox(
                            height: 130,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 5,
                              itemBuilder: (ctx, i) => _PhotoSlot(
                                localFile: _localPhotos[i],
                                existingUrl: _existingUrls[i],
                                onPick: () => _pickPhoto(i),
                                onRemove: () => _removePhoto(i),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ─── Basic info ───
                        _SectionCard(
                          title: 'المعلومات الأساسية',
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameCtrl,
                                textAlign: TextAlign.right,
                                decoration:
                                    _inputDeco('الاسم', Icons.person_outline),
                                validator: (v) =>
                                    v == null || v.isEmpty ? 'الاسم مطلوب' : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _ageCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                decoration:
                                    _inputDeco('العمر', Icons.cake_outlined),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'العمر مطلوب';
                                  final n = int.tryParse(v);
                                  if (n == null || n < 18 || n > 100) {
                                    return 'أدخل عمراً صحيحاً (18-100)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _bioCtrl,
                                maxLines: 4,
                                maxLength: 200,
                                textAlign: TextAlign.right,
                                decoration: _inputDeco(
                                    'نبذة عن نفسك', Icons.info_outline),
                                validator: (v) =>
                                    v == null || v.isEmpty ? 'النبذة مطلوبة' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ─── Social ───
                        _SectionCard(
                          title: 'وسائل التواصل الاجتماعي',
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _whatsappCtrl,
                                keyboardType: TextInputType.phone,
                                textDirection: TextDirection.ltr,
                                decoration: _inputDeco(
                                    'واتساب', Icons.phone,
                                    hint: '+964xxxxxxxxx'),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _facebookCtrl,
                                textDirection: TextDirection.ltr,
                                decoration: _inputDeco(
                                    'فيسبوك', Icons.facebook,
                                    hint: 'facebook.com/...'),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _tiktokCtrl,
                                textDirection: TextDirection.ltr,
                                decoration: _inputDeco(
                                    'تيك توك', Icons.music_note,
                                    hint: '@username'),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _instagramCtrl,
                                textDirection: TextDirection.ltr,
                                decoration: _inputDeco(
                                    'انستغرام', Icons.camera_alt_outlined,
                                    hint: '@username'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.campaign_rounded, size: 22),
                          label: const Text('نشر الإعلان',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE91E8C),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 4,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Google Login Bottom Sheet ────────────────────────────────────────────────

class _GoogleLoginSheet extends StatefulWidget {
  const _GoogleLoginSheet();
  @override
  State<_GoogleLoginSheet> createState() => _GoogleLoginSheetState();
}

class _GoogleLoginSheetState extends State<_GoogleLoginSheet> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      UserCredential result;
      if (kIsWeb) {
        result = await FirebaseAuth.instance
            .signInWithPopup(GoogleAuthProvider());
      } else {
        final gsi = GoogleSignIn();
        await gsi.signOut();
        final g = await gsi.signIn();
        if (g == null) { if (mounted) setState(() => _loading = false); return; }
        final auth = await g.authentication;
        final cred = GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        );
        result = await FirebaseAuth.instance.signInWithCredential(cred);
      }
      await FirebaseService().registerDevice(result.user!.uid);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.campaign_rounded,
              size: 48, color: Color(0xFFE91E8C)),
          const SizedBox(height: 12),
          const Text(
            'لنشر إعلانك',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3D0030)),
          ),
          const SizedBox(height: 6),
          const Text(
            'سجّل دخولاً بـ Google مرة واحدة ثم انشر إعلانك',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFBB8899), fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                side: const BorderSide(color: Color(0xFFDDDDDD)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 1,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Color(0xFFE91E8C), strokeWidth: 2.5))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24, height: 24,
                          child: CustomPaint(painter: _GoogleG()),
                        ),
                        const SizedBox(width: 12),
                        const Text('متابعة مع Google',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleG extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.width * 0.42, sw = size.width * 0.19;
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE91E8C))),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final XFile? localFile;
  final String existingUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PhotoSlot({
    required this.localFile,
    required this.existingUrl,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = localFile != null || existingUrl.isNotEmpty;

    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          GestureDetector(
            onTap: onPick,
            child: Container(
              width: 110,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.grey[200],
                border: Border.all(
                    color: const Color(0xFFE91E8C), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: hasPhoto
                    ? (localFile != null
                        ? (kIsWeb
                            ? Image.network(localFile!.path,
                                fit: BoxFit.cover, width: 110, height: 130)
                            : Image.file(File(localFile!.path),
                                fit: BoxFit.cover, width: 110, height: 130))
                        : Image.network(existingUrl,
                            fit: BoxFit.cover,
                            width: 110,
                            height: 130,
                            errorBuilder: (ctx2, e2, st2) => const Icon(
                                Icons.broken_image,
                                color: Colors.grey)))
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 36, color: Color(0xFFE91E8C)),
                          SizedBox(height: 6),
                          Text('إضافة صورة',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
              ),
            ),
          ),
          if (hasPhoto)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(3),
                  child:
                      const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
