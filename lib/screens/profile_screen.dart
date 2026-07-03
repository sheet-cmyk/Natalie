import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();

  final List<File?> _localPhotos = List.filled(5, null);
  final List<String> _existingUrls = List.filled(5, '');
  bool _saving = false;
  bool _initialLoading = true;
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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

  Future<void> _loadProfile() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      setState(() => _initialLoading = false);
      return;
    }
    _isAnonymous = authUser.isAnonymous;
    try {
      final user = await FirebaseService().getUser(authUser.uid);
      if (mounted) {
        if (user != null) {
          setState(() {
            _nameCtrl.text = user.name;
            _ageCtrl.text = user.age > 0 ? user.age.toString() : '';
            _bioCtrl.text = user.bio;
            _whatsappCtrl.text = user.whatsapp;
            _facebookCtrl.text = user.facebook;
            _tiktokCtrl.text = user.tiktok;
            _instagramCtrl.text = user.instagram;
            for (int i = 0; i < user.photoUrls.length && i < 5; i++) {
              _existingUrls[i] = user.photoUrls[i];
            }
          });
        } else if (authUser.displayName != null && authUser.displayName!.isNotEmpty) {
          // Pre-fill name from Google account for new users
          setState(() => _nameCtrl.text = authUser.displayName!);
        }
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
      setState(() => _localPhotos[index] = File(picked.path));
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _localPhotos[index] = null;
      _existingUrls[index] = '';
    });
  }

  Future<void> _save() async {
    if (_isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الزوار لا يمكنهم النشر — سجّل دخولاً بـ Google أولاً'),
          backgroundColor: Color(0xFFB45309),
          duration: Duration(seconds: 3),
        ),
      );
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
      final email = FirebaseAuth.instance.currentUser!.email ?? '';
      final service = FirebaseService();
      final List<String> finalUrls = List.filled(5, '');

      for (int i = 0; i < 5; i++) {
        if (_localPhotos[i] != null) {
          finalUrls[i] = await service.uploadPhoto(uid, _localPhotos[i]!, i);
        } else {
          finalUrls[i] = _existingUrls[i];
        }
      }

      final photoUrls = finalUrls.where((u) => u.isNotEmpty).toList();
      final name = _nameCtrl.text.trim();
      final age = int.tryParse(_ageCtrl.text.trim()) ?? 0;
      final bio = _bioCtrl.text.trim();

      final user = UserModel(
        uid: uid,
        email: email,
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

      await service.saveUser(user);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الملف الشخصي بنجاح ✓'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      if (user.published) {
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

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('خروج', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _deleteAccount() async {
    // تأكيد أول
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب', style: TextStyle(color: Colors.red)),
        content: const Text(
          'سيتم حذف حسابك وجميع بياناتك نهائياً.\nهذا الإجراء لا يمكن التراجع عنه.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // تأكيد ثانٍ
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد نهائي', style: TextStyle(color: Colors.red)),
        content: const Text('هل أنت متأكد تماماً؟ لا يمكن استعادة الحساب.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('نعم، احذف الحساب'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final uid = user.uid;
      final db = FirebaseFirestore.instance;

      // حذف البيانات من Firestore
      await db.collection('users').doc(uid).delete();
      await db.collection('ads').doc(uid).delete();

      // حذف حساب Firebase Auth
      await user.delete();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحذف: $e\nسجّل خروجاً ودخولاً ثم أعد المحاولة'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
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
        title: const Text('الملف الشخصي',
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
                  Text('جاري رفع الصور والحفظ...',
                      style: TextStyle(fontSize: 15)),
                ],
              ),
            )
          : Column(
              children: [
                if (_isAnonymous)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    color: const Color(0xFFB45309),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'أنت زائر — لا يمكنك النشر. سجّل دخولاً بـ Google للنشر.',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ─── Photos section ───
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
                          decoration: _inputDeco('الاسم', Icons.person_outline),
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

                  // ─── Social media ───
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
                    icon: Icon(
                      _isAnonymous
                          ? Icons.lock_outline_rounded
                          : Icons.save_rounded,
                      size: 22,
                    ),
                    label: Text(
                      _isAnonymous
                          ? 'سجّل دخولاً بـ Google للنشر'
                          : 'حفظ الملف الشخصي',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAnonymous
                          ? const Color(0xFF78350F)
                          : const Color(0xFFE91E8C),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── تسجيل الخروج ──
                  if (!_isAnonymous)
                    OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, color: Colors.orange),
                      label: const Text('تسجيل الخروج',
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: const BorderSide(color: Colors.orange, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),

                  if (!_isAnonymous) const SizedBox(height: 12),

                  // ── حذف الحساب ──
                  OutlinedButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                    label: const Text('حذف الحساب نهائياً',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
  final File? localFile;
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
                        ? Image.file(localFile!,
                            fit: BoxFit.cover,
                            width: 110,
                            height: 130)
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
