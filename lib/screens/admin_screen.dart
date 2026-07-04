import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/ad_model.dart';
import '../models/user_model.dart';
import 'post_detail_screen.dart';

const String kAdminEmail = 'hussein1sheet@gmail.com';
const String kAdminPin   = 'Alzain2020';
const List<String> kAdminUids = [
  'zO8KCjQ9iYXTBg7xe7Ru3ZPL7yF3',
  '7LYJJ9FR6eU5YYVxWOdn7Ok2p4t1',
  'QTzvO5yuV7aZ24PC0qHUEyIxrVv2',
  '7KyzgxPXNDXftSLxSLzSNNLJwAS2',
];

// PIN-granted admin for current session
bool _pinAdminGranted = false;
void grantPinAdmin() => _pinAdminGranted = true;

bool isAdminUser() {
  if (_pinAdminGranted) return true;
  final user = FirebaseAuth.instance.currentUser;
  return user?.email == kAdminEmail || kAdminUids.contains(user?.uid);
}

// ─── Admin Screen ─────────────────────────────────────────────────────────────

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF5FA),
        appBar: AppBar(
          title: const Text('لوحة الإدارة',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          backgroundColor: const Color(0xFFE91E8C),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.people_rounded), text: 'المستخدمون'),
              Tab(icon: Icon(Icons.campaign_rounded), text: 'الإعلانات'),
              Tab(icon: Icon(Icons.link_rounded), text: 'روابط التواصل'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UsersTab(),
            _AdsTab(),
            _SocialLinksTab(),
          ],
        ),
      ),
    );
  }
}

// ─── Users Tab ────────────────────────────────────────────────────────────────

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE91E8C)));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text('لا يوجد مستخدمون'));
        }
        final users = snap.data!.docs
            .map((d) => UserModel.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList();
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) => _UserTile(user: users[i]),
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;
  const _UserTile({required this.user});

  Future<void> _delete(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('حذف المستخدم'),
        content: Text('هل تريد حذف "${user.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
    }
  }

  void _edit(BuildContext ctx) {
    final ad = AdModel(
      uid: user.uid,
      name: user.name,
      age: user.age,
      bio: user.bio,
      whatsapp: user.whatsapp,
      facebook: user.facebook,
      tiktok: user.tiktok,
      instagram: user.instagram,
      photoUrls: user.photoUrls,
      published: user.published,
    );
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdEditSheet(ad: ad, collection: 'users'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCCE8)),
        boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.06), blurRadius: 6)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF8D7E8),
          backgroundImage: user.photoUrls.isNotEmpty
              ? NetworkImage(user.photoUrls.first)
              : null,
          child: user.photoUrls.isEmpty
              ? const Icon(Icons.person, color: Color(0xFFE91E8C))
              : null,
        ),
        title: Text(user.name.isNotEmpty ? user.name : '(بدون اسم)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(user.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Color(0xFF7C3AED), size: 20),
              onPressed: () => _edit(context),
              tooltip: 'تعديل',
            ),
            IconButton(
              icon: const Icon(Icons.visibility_rounded, color: Color(0xFFE91E8C), size: 20),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PostDetailScreen.fromProfile(user)),
              ),
              tooltip: 'عرض',
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
              onPressed: () => _delete(context),
              tooltip: 'حذف',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ads Tab ──────────────────────────────────────────────────────────────────

class _AdsTab extends StatelessWidget {
  const _AdsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ads').snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE91E8C)));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text('لا يوجد إعلانات'));
        }
        final ads = snap.data!.docs
            .map((d) => AdModel.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList();
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: ads.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) => _AdTile(ad: ads[i]),
        );
      },
    );
  }
}

class _AdTile extends StatelessWidget {
  final AdModel ad;
  const _AdTile({required this.ad});

  Future<void> _delete(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('حذف الإعلان'),
        content: Text('هل تريد حذف إعلان "${ad.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('ads').doc(ad.uid).delete();
    }
  }

  void _edit(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdEditSheet(ad: ad, collection: 'ads'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCCE8)),
        boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.06), blurRadius: 6)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFF8D7E8),
          backgroundImage: ad.photoUrls.isNotEmpty
              ? NetworkImage(ad.photoUrls.first)
              : null,
          child: ad.photoUrls.isEmpty
              ? const Icon(Icons.campaign_rounded, color: Color(0xFFE91E8C))
              : null,
        ),
        title: Text(ad.name.isNotEmpty ? ad.name : '(بدون اسم)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          '${ad.age} سنة  •  ${ad.published ? "منشور" : "غير منشور"}',
          style: TextStyle(
              fontSize: 12,
              color: ad.published ? Colors.green[600] : Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Color(0xFF7C3AED), size: 20),
              onPressed: () => _edit(context),
              tooltip: 'تعديل',
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
              onPressed: () => _delete(context),
              tooltip: 'حذف',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ad Edit Sheet (قابل للاستخدام لإعلانات ومستخدمين) ───────────────────────

class AdEditSheet extends StatefulWidget {
  final AdModel ad;
  final String collection; // 'ads' أو 'users'

  const AdEditSheet({super.key, required this.ad, this.collection = 'ads'});

  @override
  State<AdEditSheet> createState() => AdEditSheetState();
}

class AdEditSheetState extends State<AdEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _bio;
  late final TextEditingController _whatsapp;
  late final TextEditingController _facebook;
  late final TextEditingController _tiktok;
  late final TextEditingController _instagram;
  bool _published = false;
  bool _saving = false;

  late List<String> _photos;
  bool _photoLoading = false;

  @override
  void initState() {
    super.initState();
    _photos = List<String>.from(widget.ad.photoUrls);
    _name      = TextEditingController(text: widget.ad.name);
    _age       = TextEditingController(text: widget.ad.age.toString());
    _bio       = TextEditingController(text: widget.ad.bio);
    _whatsapp  = TextEditingController(text: widget.ad.whatsapp);
    _facebook  = TextEditingController(text: widget.ad.facebook);
    _tiktok    = TextEditingController(text: widget.ad.tiktok);
    _instagram = TextEditingController(text: widget.ad.instagram);
    _published = widget.ad.published;
  }

  @override
  void dispose() {
    for (final c in [_name, _age, _bio, _whatsapp, _facebook, _tiktok, _instagram]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── إضافة صورة ────────────────────────────────────────────────────────────

  Future<void> _addPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _photoLoading = true);
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref('${widget.collection}/${widget.ad.uid}/photo_$ts.jpg');
      final bytes = await picked.readAsBytes();
      final task = await ref.putData(
          bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await task.ref.getDownloadURL();
      if (mounted) setState(() => _photos.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('فشل رفع الصورة: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _photoLoading = false);
    }
  }

  // ── حذف صورة ──────────────────────────────────────────────────────────────

  Future<void> _removePhoto(int i) async {
    final url = _photos[i];
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (_) {}
    setState(() => _photos.removeAt(i));
  }

  // ── حفظ ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection(widget.collection)
        .doc(widget.ad.uid)
        .update({
      'name'      : _name.text.trim(),
      'age'       : int.tryParse(_age.text.trim()) ?? widget.ad.age,
      'bio'       : _bio.text.trim(),
      'whatsapp'  : _whatsapp.text.trim(),
      'facebook'  : _facebook.text.trim(),
      'tiktok'    : _tiktok.text.trim(),
      'instagram' : _instagram.text.trim(),
      'published' : _published,
      'photoUrls' : _photos,
      'updatedAt' : FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.pop(context);
  }

  // ── حذف المنشور كاملاً ────────────────────────────────────────────────────

  Future<void> _deleteRecord() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await FirebaseFirestore.instance
          .collection(widget.collection)
          .doc(widget.ad.uid)
          .delete();
      if (mounted) Navigator.pop(context);
    }
  }

  // ── عرض المنشور ───────────────────────────────────────────────────────────

  void _viewPost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          photos    : _photos,
          name      : _name.text.trim().isEmpty ? widget.ad.name : _name.text.trim(),
          age       : int.tryParse(_age.text.trim()) ?? widget.ad.age,
          bio       : _bio.text.trim(),
          whatsapp  : _whatsapp.text.trim(),
          facebook  : _facebook.text.trim(),
          tiktok    : _tiktok.text.trim(),
          instagram : _instagram.text.trim(),
          postId    : '${widget.collection}_${widget.ad.uid}',
          ownerUid  : widget.ad.uid,
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── مقبض ──
            const SizedBox(height: 10),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),

            // ── شريط العنوان ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Text('تعديل المنشور',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // زر عرض
                  IconButton(
                    icon: const Icon(Icons.visibility_rounded,
                        color: Color(0xFF7C3AED)),
                    onPressed: _viewPost,
                    tooltip: 'عرض المنشور',
                  ),
                  // زر حذف
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, color: Colors.red),
                    onPressed: _deleteRecord,
                    tooltip: 'حذف المنشور',
                  ),
                  // زر إلغاء
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── المحتوى ──
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 16),

                  // ── قسم الصور ──────────────────────────────────────
                  const Text('الصور',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF3D0030))),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 115,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // الصور الحالية
                        ..._photos.asMap().entries.map((e) => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 90,
                              height: 115,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                image: DecorationImage(
                                  image: NetworkImage(e.value),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: -4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removePhoto(e.key),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 15),
                                ),
                              ),
                            ),
                          ],
                        )),

                        // زر إضافة صورة
                        GestureDetector(
                          onTap: _photoLoading ? null : _addPhoto,
                          child: Container(
                            width: 90,
                            height: 115,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFFE91E8C),
                                  width: 1.5),
                              color: const Color(0xFFFFF0F7),
                            ),
                            child: _photoLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: Color(0xFFE91E8C),
                                        strokeWidth: 2))
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_rounded,
                                          color: Color(0xFFE91E8C), size: 30),
                                      SizedBox(height: 6),
                                      Text('إضافة',
                                          style: TextStyle(
                                              color: Color(0xFFE91E8C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // ── حقول النص ──────────────────────────────────────
                  _Field(ctrl: _name, label: 'الاسم', icon: Icons.person_outline),
                  _Field(
                      ctrl: _age,
                      label: 'العمر',
                      icon: Icons.cake_outlined,
                      keyboardType: TextInputType.number),
                  _Field(
                      ctrl: _bio,
                      label: 'البيو',
                      icon: Icons.notes_rounded,
                      maxLines: 3),
                  _Field(
                      ctrl: _whatsapp,
                      label: 'واتساب',
                      icon: Icons.chat_rounded,
                      iconColor: const Color(0xFF25D366)),
                  _Field(
                      ctrl: _facebook,
                      label: 'فيسبوك',
                      icon: Icons.facebook_rounded,
                      iconColor: const Color(0xFF1877F2)),
                  _Field(
                      ctrl: _tiktok,
                      label: 'تيكتوك',
                      icon: Icons.music_note_rounded,
                      iconColor: Colors.black),
                  _Field(
                      ctrl: _instagram,
                      label: 'انستغرام',
                      icon: Icons.camera_alt_rounded,
                      iconColor: const Color(0xFFE1306C)),

                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _published,
                    onChanged: (v) => setState(() => _published = v),
                    title: const Text('منشور'),
                    activeThumbColor: const Color(0xFFE91E8C),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),

                  // ── زر الحفظ ───────────────────────────────────────
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E8C),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('حفظ التعديلات',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Field Helper ─────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final Color? iconColor;
  final TextInputType? keyboardType;
  final int maxLines;
  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.iconColor,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon:
              Icon(icon, color: iconColor ?? const Color(0xFFE91E8C), size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE91E8C)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

// ─── Social Links Tab ─────────────────────────────────────────────────────────

class _SocialLinksTab extends StatefulWidget {
  const _SocialLinksTab();

  @override
  State<_SocialLinksTab> createState() => _SocialLinksTabState();
}

class _SocialLinksTabState extends State<_SocialLinksTab> {
  final _whatsapp      = TextEditingController();
  final _facebook      = TextEditingController();
  final _tiktok        = TextEditingController();
  final _instagram     = TextEditingController();
  final _snapchat      = TextEditingController();
  final _gift          = TextEditingController();
  final _subscription  = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  final _doc =
      FirebaseFirestore.instance.collection('config').doc('social_links');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await _doc.get();
    final data = snap.data() ?? {};
    _whatsapp.text     = data['whatsapp']      ?? '';
    _facebook.text     = data['facebook']      ?? '';
    _tiktok.text       = data['tiktok']        ?? '';
    _instagram.text    = data['instagram']     ?? '';
    _snapchat.text     = data['snapchat']      ?? '';
    _gift.text         = data['gift']          ?? '';
    _subscription.text = data['subscription']  ?? '';
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _doc.set({
        'whatsapp'     : _whatsapp.text.trim(),
        'facebook'     : _facebook.text.trim(),
        'tiktok'       : _tiktok.text.trim(),
        'instagram'    : _instagram.text.trim(),
        'snapchat'     : _snapchat.text.trim(),
        'gift'         : _gift.text.trim(),
        'subscription' : _subscription.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم حفظ الروابط بنجاح ✓'),
              backgroundColor: Color(0xFF25D366)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في الحفظ: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _whatsapp.dispose();
    _facebook.dispose();
    _tiktok.dispose();
    _instagram.dispose();
    _snapchat.dispose();
    _gift.dispose();
    _subscription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFE91E8C)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('روابط أزرار الصفحة الرئيسية',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF3D0030))),
          const SizedBox(height: 6),
          Text('هذه الروابط تظهر في أزرار السوشيال ميديا في الأسفل',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 24),
          _SocialField(
            ctrl: _whatsapp,
            label: 'رقم واتساب (مع رمز الدولة)',
            hint: 'مثال: 9647801234567',
            icon: Icons.chat_rounded,
            color: const Color(0xFF25D366),
          ),
          _SocialField(
            ctrl: _facebook,
            label: 'رابط فيسبوك',
            hint: 'مثال: https://facebook.com/page',
            icon: Icons.facebook_rounded,
            color: const Color(0xFF1877F2),
          ),
          _SocialField(
            ctrl: _tiktok,
            label: 'رابط تيكتوك',
            hint: 'مثال: https://tiktok.com/@user',
            icon: Icons.music_note_rounded,
            color: Colors.black,
          ),
          _SocialField(
            ctrl: _instagram,
            label: 'رابط انستغرام',
            hint: 'مثال: https://instagram.com/user',
            icon: Icons.camera_alt_rounded,
            color: const Color(0xFFE1306C),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          const Text('أزرار الإجراءات',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF3D0030))),
          const SizedBox(height: 16),
          _SocialField(
            ctrl: _snapchat,
            label: 'رابط مجموعة وتياب 🇺🇸',
            hint: 'مثال: https://chat.whatsapp.com/...',
            icon: Icons.chat_rounded,
            color: const Color(0xFF25D366),
          ),
          _SocialField(
            ctrl: _gift,
            label: 'رابط الهداية',
            hint: 'مثال: https://...',
            icon: Icons.card_giftcard_rounded,
            color: const Color(0xFFE91E8C),
          ),
          _SocialField(
            ctrl: _subscription,
            label: 'رابط الاشتراك',
            hint: 'مثال: https://...',
            icon: Icons.stars_rounded,
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_rounded),
            label: const Text('حفظ الروابط',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E8C),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final Color color;
  const _SocialField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: color)),
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: color.withValues(alpha: 0.3))),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: color.withValues(alpha: 0.3)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
