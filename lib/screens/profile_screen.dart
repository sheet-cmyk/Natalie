import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'admin_screen.dart' show isAdminUser, resetAdminState;
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userId = '';
  String _avatarUrl = '';
  bool _loading = true;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loading = false); return; }

    if (isAdminUser()) {
      final doc = await FirebaseFirestore.instance
          .collection('config').doc('admin_profile').get();
      final data = doc.data() ?? {};
      if (mounted) {
        setState(() {
          _userId = data['name'] as String? ?? 'أدمن';
          _avatarUrl = data['photoUrl'] as String? ?? '';
          _loading = false;
        });
      }
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    final urls = (data['photoUrls'] as List?)?.cast<String>() ?? [];
    if (mounted) {
      setState(() {
        _userId = data['username'] as String? ?? '';
        _avatarUrl = urls.isNotEmpty ? urls.first : '';
        _loading = false;
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ts = DateTime.now().millisecondsSinceEpoch;
      String url;

      if (isAdminUser()) {
        final ref = FirebaseStorage.instance.ref('config/admin_photo_$ts.jpg');
        final task = await ref.putData(
            bytes, SettableMetadata(contentType: 'image/jpeg'));
        url = await task.ref.getDownloadURL();
        await FirebaseFirestore.instance
            .collection('config').doc('admin_profile')
            .set({'photoUrl': url, 'updatedAt': FieldValue.serverTimestamp()},
                SetOptions(merge: true));
      } else {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final ref = FirebaseStorage.instance.ref('users/$uid/photo_0_$ts.jpg');
        final task = await ref.putData(
            bytes, SettableMetadata(contentType: 'image/jpeg'));
        url = await task.ref.getDownloadURL();
        final doc = await FirebaseFirestore.instance
            .collection('users').doc(uid).get();
        final existing = (doc.data()?['photoUrls'] as List?)
                ?.cast<String>() ?? [];
        await FirebaseFirestore.instance
            .collection('users').doc(uid)
            .update({'photoUrls': [url, ...existing.skip(1)]});
      }

      if (mounted) setState(() { _avatarUrl = url; _uploading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    resetAdminState();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
    }
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف الحساب',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
            'سيتم حذف حسابك وبياناتك نهائياً.\nهذا الإجراء لا يمكن التراجع عنه.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final uid = user.uid;
      final db = FirebaseFirestore.instance;
      await db.collection('users').doc(uid).delete();
      await db.collection('ads').doc(uid).delete();
      await user.delete();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFFE91E8C))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE91E8C),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('حسابي',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _saving
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE91E8C)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // ── الصورة الشخصية ────────────────────────────────────
                  GestureDetector(
                    onTap: _uploading ? null : _pickAndUploadAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFE91E8C), width: 3),
                            color: const Color(0xFFFFCCE8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE91E8C)
                                    .withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _uploading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: Color(0xFFE91E8C),
                                        strokeWidth: 2))
                                : _avatarUrl.isNotEmpty
                                    ? Image.network(
                                        _avatarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            const Icon(Icons.person_rounded,
                                                color: Color(0xFFE91E8C),
                                                size: 56),
                                      )
                                    : const Icon(Icons.person_rounded,
                                        color: Color(0xFFE91E8C), size: 56),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE91E8C),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 17),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Text('اضغط لتغيير الصورة',
                      style: TextStyle(
                          color: Color(0xFFBB8899), fontSize: 12)),

                  const SizedBox(height: 28),

                  // ── الـ ID ────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFFFCCE8), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFE91E8C).withValues(alpha: 0.08),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE0F2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                              isAdminUser()
                                  ? Icons.admin_panel_settings_rounded
                                  : Icons.tag_rounded,
                              color: Color(0xFFE91E8C), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAdminUser() ? 'الاسم' : 'الـ ID الخاص بك',
                                style: const TextStyle(
                                    color: Color(0xFFBB8899), fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(
                                _userId.isNotEmpty ? _userId : '—',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3D0030),
                                    letterSpacing: 2),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.lock_outline_rounded,
                            color: Color(0xFFBB8899), size: 20),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── تسجيل الخروج ──────────────────────────────────────
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded,
                        color: Colors.orange),
                    label: const Text('تسجيل الخروج',
                        style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      side: const BorderSide(color: Colors.orange, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),

                  if (!isAdminUser()) ...[
                    const SizedBox(height: 14),

                    // ── حذف الحساب ────────────────────────────────────────
                    OutlinedButton.icon(
                      onPressed: _deleteAccount,
                      icon: const Icon(Icons.delete_forever_rounded,
                          color: Colors.red),
                      label: const Text('حذف الحساب نهائياً',
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
