import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/ad_model.dart';
import '../services/firebase_service.dart';

class AdScreen extends StatefulWidget {
  const AdScreen({super.key});

  @override
  State<AdScreen> createState() => _AdScreenState();
}

class _AdScreenState extends State<AdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _ageCtrl      = TextEditingController();
  final _bioCtrl      = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _tiktokCtrl   = TextEditingController();
  final _instagramCtrl = TextEditingController();

  final List<XFile?> _localPhotos = List.filled(5, null);
  final List<String> _existingUrls = List.filled(5, '');
  bool _saving = false;
  bool _initialLoading = true;
  bool _wasPublished = false;
  bool _isPending = false;

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
    try {
      final ad = await FirebaseService().getAd(authUser.uid);
      if (mounted && ad != null) {
        setState(() {
          _nameCtrl.text     = ad.name;
          _ageCtrl.text      = ad.age > 0 ? ad.age.toString() : '';
          _bioCtrl.text      = ad.bio;
          _whatsappCtrl.text = ad.whatsapp;
          _facebookCtrl.text = ad.facebook;
          _tiktokCtrl.text   = ad.tiktok;
          _instagramCtrl.text = ad.instagram;
          _wasPublished      = ad.published;
          _isPending         = ad.pendingPublish;
          for (int i = 0; i < ad.photoUrls.length && i < 5; i++) {
            _existingUrls[i] = ad.photoUrls[i];
          }
        });
        return;
      }
      // ملء من الملف الشخصي إن لم يكن له إعلان
      final profile = await FirebaseService().getUser(authUser.uid);
      if (mounted && profile != null) {
        setState(() {
          _nameCtrl.text      = profile.name;
          _ageCtrl.text       = profile.age > 0 ? profile.age.toString() : '';
          _bioCtrl.text       = profile.bio;
          _whatsappCtrl.text  = profile.whatsapp;
          _facebookCtrl.text  = profile.facebook;
          _tiktokCtrl.text    = profile.tiktok;
          _instagramCtrl.text = profile.instagram;
          for (int i = 0; i < profile.photoUrls.length && i < 5; i++) {
            _existingUrls[i] = profile.photoUrls[i];
          }
        });
      }
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _pickPhoto(int index) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 1080, imageQuality: 85);
    if (picked != null && mounted) setState(() => _localPhotos[index] = picked);
  }

  void _removePhoto(int index) {
    setState(() { _localPhotos[index] = null; _existingUrls[index] = ''; });
  }

  bool get _isComplete {
    final name = _nameCtrl.text.trim();
    final age  = int.tryParse(_ageCtrl.text.trim()) ?? 0;
    final bio  = _bioCtrl.text.trim();
    final hasPhoto = _existingUrls.any((u) => u.isNotEmpty) ||
        _localPhotos.any((f) => f != null);
    return name.isNotEmpty && age >= 18 && bio.isNotEmpty && hasPhoto;
  }

  // ── حفظ المسودة فقط (بدون نشر) ─────────────────────────────────────────────
  Future<void> _save() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    if (!_formKey.currentState!.validate()) return;

    final hasPhoto = _localPhotos.any((f) => f != null) ||
        _existingUrls.any((u) => u.isNotEmpty);
    if (!hasPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('يرجى إضافة صورة واحدة على الأقل'),
        backgroundColor: Colors.orange,
      ));
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

      final ad = AdModel(
        uid: uid,
        name: _nameCtrl.text.trim(),
        age: int.tryParse(_ageCtrl.text.trim()) ?? 0,
        bio: _bioCtrl.text.trim(),
        whatsapp: _whatsappCtrl.text.trim(),
        facebook: _facebookCtrl.text.trim(),
        tiktok: _tiktokCtrl.text.trim(),
        instagram: _instagramCtrl.text.trim(),
        photoUrls: photoUrls,
        published: _wasPublished,
        pendingPublish: _isPending,
      );

      await service.saveAd(ad);

      if (!mounted) return;
      // تحديث URLs المحلية
      for (int i = 0; i < photoUrls.length && i < 5; i++) {
        _existingUrls[i] = photoUrls[i];
        _localPhotos[i] = null;
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم حفظ الإعلان ✓'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── طلب النشر ───────────────────────────────────────────────────────────────
  Future<void> _requestPublish() async {
    if (!_isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('أكمل إعلانك أولاً (اسم، عمر، بيو، صورة)'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    // احفظ أولاً ثم اطلب
    await _save();
    if (!mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('ads').doc(uid).update({
        'pendingPublish': true,
        'requestedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() { _isPending = true; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم إرسال الطلب ✓ انتظر موافقة الأدمن'),
          backgroundColor: Color(0xFF7C3AED),
          duration: Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
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
            child: const Text('حفظ',
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
                  Text('جاري الحفظ...', style: TextStyle(fontSize: 15)),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ─── صور ──────────────────────────────────────────────
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

                  // ─── معلومات أساسية ────────────────────────────────────
                  _SectionCard(
                    title: 'المعلومات الأساسية',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          textAlign: TextAlign.right,
                          decoration: _inputDeco('الاسم', Icons.person_outline),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'الاسم مطلوب' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _ageCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          decoration: _inputDeco('العمر', Icons.cake_outlined),
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
                          decoration:
                              _inputDeco('نبذة عن نفسك', Icons.info_outline),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'النبذة مطلوبة' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── وسائل التواصل ─────────────────────────────────────
                  _SectionCard(
                    title: 'وسائل التواصل الاجتماعي',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _whatsappCtrl,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          decoration: _inputDeco('واتساب', Icons.phone,
                              hint: '+964xxxxxxxxx'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _facebookCtrl,
                          textDirection: TextDirection.ltr,
                          decoration: _inputDeco('فيسبوك', Icons.facebook,
                              hint: 'facebook.com/...'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _tiktokCtrl,
                          textDirection: TextDirection.ltr,
                          decoration: _inputDeco('تيك توك', Icons.music_note,
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

                  // ─── زر الحفظ ──────────────────────────────────────────
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_rounded, size: 22),
                    label: const Text('حفظ الإعلان',
                        style:
                            TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E8C),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ─── بطاقة الحالة + زر طلب النشر ──────────────────────
                  _AdStatusCard(
                    isPublished: _wasPublished,
                    isPending: _isPending,
                    onRequest: _saving ? null : _requestPublish,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// ─── Ad Status Card ───────────────────────────────────────────────────────────

class _AdStatusCard extends StatelessWidget {
  final bool isPublished;
  final bool isPending;
  final VoidCallback? onRequest;
  const _AdStatusCard(
      {required this.isPublished,
      required this.isPending,
      required this.onRequest});

  @override
  Widget build(BuildContext context) {
    if (isPublished) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8FFF0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: Color(0xFF22C55E), size: 26),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إعلانك منشور ✓',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                          fontSize: 15)),
                  SizedBox(height: 2),
                  Text('يظهر إعلانك للجميع في الصفحة الرئيسية',
                      style:
                          TextStyle(color: Color(0xFF15803D), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isPending) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF7C3AED), width: 1.2),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_top_rounded,
                color: Color(0xFF7C3AED), size: 26),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('بانتظار موافقة الأدمن',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4C1D95),
                          fontSize: 15)),
                  SizedBox(height: 2),
                  Text('تم إرسال طلبك، سيتم مراجعته قريباً',
                      style:
                          TextStyle(color: Color(0xFF6D28D9), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9F0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Colors.orange.withValues(alpha: 0.5), width: 1.2),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.orange, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'إعلانك غير منشور — احفظه كاملاً ثم اضغط "طلب النشر"',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: onRequest,
          icon: const Icon(Icons.send_rounded, size: 20),
          label: const Text('طلب النشر',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 3,
          ),
        ),
      ],
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────

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

// ─── Photo Slot ───────────────────────────────────────────────────────────────

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
                border:
                    Border.all(color: const Color(0xFFE91E8C), width: 1.5),
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
                            errorBuilder: (_, _, _) => const Icon(
                                Icons.broken_image,
                                color: Colors.grey)))
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 36, color: Color(0xFFE91E8C)),
                          SizedBox(height: 6),
                          Text('إضافة صورة',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey)),
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
