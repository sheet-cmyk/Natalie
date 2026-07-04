import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/ad_model.dart';
import '../models/user_model.dart';
import 'chat_screen.dart';
import 'post_detail_screen.dart';

const String kAdminEmail = 'hussein1sheet@gmail.com';
const String kAdminPin   = 'Alzain2020';
const List<String> kAdminUids = [
  'zO8KCjQ9iYXTBg7xe7Ru3ZPL7yF3',
  '7LYJJ9FR6eU5YYVxWOdn7Ok2p4t1',
  'QTzvO5yuV7aZ24PC0qHUEyIxrVv2',
  '7KyzgxPXNDXftSLxSLzSNNLJwAS2',
];

const String _kAdminSessionSecret = 'om_admin_session_v1_granted';

bool _pinAdminGranted = false;

Future<void> grantPinAdmin() async {
  _pinAdminGranted = true;
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('admin_sessions')
          .doc(uid)
          .set({
        'secret': _kAdminSessionSecret,
        'grantedAt': FieldValue.serverTimestamp(),
      });
    }
  } catch (_) {}
}

/// Restore admin state from Firestore (called on app start / page refresh on web)
Future<void> initAdminState() async {
  if (_pinAdminGranted) return;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  try {
    final doc = await FirebaseFirestore.instance
        .collection('admin_sessions')
        .doc(uid)
        .get();
    if (doc.exists && doc.data()?['secret'] == _kAdminSessionSecret) {
      _pinAdminGranted = true;
    }
  } catch (_) {}
}

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
          title: const Text('Admin',
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
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              Tab(icon: Icon(Icons.link_rounded), text: 'الروابط'),
              Tab(icon: Icon(Icons.grid_view_rounded), text: 'المنشورات'),
              Tab(icon: Icon(Icons.manage_accounts_rounded), text: 'Admin Profile'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SocialLinksTab(),
            _AllPostsTab(),
            _AdminProfileTab(),
          ],
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
  final _whatsapp     = TextEditingController();
  final _facebook     = TextEditingController();
  final _tiktok       = TextEditingController();
  final _instagram    = TextEditingController();
  final _snapchat     = TextEditingController();
  final _gift         = TextEditingController();
  final _subscription = TextEditingController();
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
    _whatsapp.text     = data['whatsapp']     ?? '';
    _facebook.text     = data['facebook']     ?? '';
    _tiktok.text       = data['tiktok']       ?? '';
    _instagram.text    = data['instagram']    ?? '';
    _snapchat.text     = data['snapchat']     ?? '';
    _gift.text         = data['gift']         ?? '';
    _subscription.text = data['subscription'] ?? '';
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _doc.set({
        'whatsapp'    : _whatsapp.text.trim(),
        'facebook'    : _facebook.text.trim(),
        'tiktok'      : _tiktok.text.trim(),
        'instagram'   : _instagram.text.trim(),
        'snapchat'    : _snapchat.text.trim(),
        'gift'        : _gift.text.trim(),
        'subscription': _subscription.text.trim(),
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
          const _SectionHeader(
            icon: Icons.share_rounded,
            color: Color(0xFFE91E8C),
            title: 'روابط التواصل الاجتماعي',
            subtitle: 'تظهر في شريط الروابط في الصفحة الرئيسية',
          ),
          const SizedBox(height: 20),
          _SocialField(ctrl: _whatsapp, label: 'رقم واتساب (مع رمز الدولة)',
              hint: 'مثال: 9647801234567',
              icon: Icons.chat_rounded, color: const Color(0xFF25D366)),
          _SocialField(ctrl: _facebook, label: 'رابط فيسبوك',
              hint: 'مثال: https://facebook.com/page',
              icon: Icons.facebook_rounded, color: const Color(0xFF1877F2)),
          _SocialField(ctrl: _tiktok, label: 'رابط تيكتوك',
              hint: 'مثال: https://tiktok.com/@user',
              icon: Icons.music_note_rounded, color: Colors.black87),
          _SocialField(ctrl: _instagram, label: 'رابط انستغرام',
              hint: 'مثال: https://instagram.com/user',
              icon: Icons.camera_alt_rounded, color: const Color(0xFFE1306C)),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          const _SectionHeader(
            icon: Icons.touch_app_rounded,
            color: Color(0xFF7C3AED),
            title: 'أزرار الإجراءات',
            subtitle: 'روابط أزرار الهداية والاشتراك في الصفحة الرئيسية',
          ),
          const SizedBox(height: 16),
          _SocialField(ctrl: _snapchat, label: 'رابط مجموعة واتساب',
              hint: 'مثال: https://chat.whatsapp.com/...',
              icon: Icons.group_rounded, color: const Color(0xFF25D366)),
          _SocialField(ctrl: _gift, label: 'رابط الهداية',
              hint: 'مثال: https://...',
              icon: Icons.card_giftcard_rounded,
              color: const Color(0xFFE91E8C)),
          _SocialField(ctrl: _subscription, label: 'رابط الاشتراك',
              hint: 'مثال: https://...',
              icon: Icons.stars_rounded, color: const Color(0xFF7C3AED)),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_rounded),
            label: const Text('حفظ الروابط',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E8C),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── All Posts Tab ────────────────────────────────────────────────────────────

class _AllPostsTab extends StatefulWidget {
  const _AllPostsTab();

  @override
  State<_AllPostsTab> createState() => _AllPostsTabState();
}

class _AllPostsTabState extends State<_AllPostsTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  // filter: 'all' | 'users' | 'ads' | 'blocked' | 'requests'
  String _filter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── شريط الفلتر والبحث ─────────────────────────────────────────
        Container(
          color: const Color(0xFF1A0012),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            children: [
              // حقل البحث
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFE91E8C).withValues(alpha: 0.6)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو المعرّف...',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12),
                    prefixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Color(0xFFE91E8C), size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            })
                        : null,
                    suffixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFFE91E8C), size: 18),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: 8),
              // فلاتر
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FChip(label: 'الكل',     value: 'all',      current: _filter, onTap: (v) => setState(() => _filter = v)),
                    _FChip(label: 'مستخدمون', value: 'users',    current: _filter, onTap: (v) => setState(() => _filter = v)),
                    _FChip(label: 'إعلانات',  value: 'ads',      current: _filter, onTap: (v) => setState(() => _filter = v)),
                    _FChip(label: 'محظور',    value: 'blocked',  current: _filter, onTap: (v) => setState(() => _filter = v)),
                    _FChip(label: '🕐 طلبات', value: 'requests', current: _filter, onTap: (v) => setState(() => _filter = v)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── القائمة ──────────────────────────────────────────────────────
        Expanded(
          child: _PostsList(query: _query, filter: _filter),
        ),
      ],
    );
  }
}

class _PostsList extends StatelessWidget {
  final String query;
  final String filter;
  const _PostsList({required this.query, required this.filter});

  bool _matchesQuery(String name, String username, String q) {
    if (q.isEmpty) return true;
    final lq = q.toLowerCase();
    return name.toLowerCase().contains(lq) ||
        username.toLowerCase().contains(lq);
  }

  @override
  Widget build(BuildContext context) {
    // نجمع users + ads في stream واحد
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (ctx, userSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('ads').snapshots(),
          builder: (ctx2, adSnap) {
            if (userSnap.connectionState == ConnectionState.waiting ||
                adSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFE91E8C)));
            }

            // بناء القائمة الموحدة
            final List<_PostEntry> entries = [];

            if (filter != 'ads') {
              for (final doc in (userSnap.data?.docs ?? [])) {
                final data = doc.data() as Map<String, dynamic>;
                final user = UserModel.fromMap(doc.id, data);
                if (filter == 'blocked'  && !user.blocked) continue;
                if (filter == 'requests' && !user.pendingPublish) continue;
                if (!_matchesQuery(user.name, user.username, query)) continue;
                entries.add(_PostEntry.fromUser(user));
              }
            }

            if (filter != 'users' && filter != 'blocked') {
              for (final doc in (adSnap.data?.docs ?? [])) {
                final data = doc.data() as Map<String, dynamic>;
                final ad = AdModel.fromMap(doc.id, data);
                // فلتر طلبات: أظهر الإعلانات المنتظرة فقط
                if (filter == 'requests' && !ad.pendingPublish) continue;
                if (!_matchesQuery(ad.name, '', query)) continue;
                entries.add(_PostEntry.fromAd(ad));
              }
            }

            // ترتيب: محظور أولاً، ثم منشور، ثم اسم
            entries.sort((a, b) {
              if (a.blocked && !b.blocked) return -1;
              if (!a.blocked && b.blocked) return 1;
              if (a.published && !b.published) return -1;
              if (!a.published && b.published) return 1;
              return a.name.compareTo(b.name);
            });

            // رأس العداد
            final total = (userSnap.data?.docs.length ?? 0) +
                (adSnap.data?.docs.length ?? 0);

            if (entries.isEmpty) {
              return Column(
                children: [
                  _CountHeader(shown: 0, total: total),
                  Expanded(
                    child: Center(
                      child: Icon(Icons.search_off_rounded,
                          size: 60,
                          color: Colors.pink.withValues(alpha: 0.2)),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _CountHeader(shown: entries.length, total: total),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _PostTile(entry: entries[i]),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── Post Entry (unified model) ───────────────────────────────────────────────

class _PostEntry {
  final String uid;
  final String name;
  final String username;
  final String photo;
  final int age;
  final String bio;
  final bool published;
  final bool blocked;
  final bool pendingPublish;
  final bool isAd;
  final UserModel? user;
  final AdModel? ad;

  const _PostEntry({
    required this.uid,
    required this.name,
    required this.username,
    required this.photo,
    required this.age,
    required this.bio,
    required this.published,
    required this.blocked,
    required this.pendingPublish,
    required this.isAd,
    this.user,
    this.ad,
  });

  factory _PostEntry.fromUser(UserModel u) => _PostEntry(
        uid: u.uid,
        name: u.name,
        username: u.username,
        photo: u.photoUrls.isNotEmpty ? u.photoUrls.first : '',
        age: u.age,
        bio: u.bio,
        published: u.published,
        blocked: u.blocked,
        pendingPublish: u.pendingPublish,
        isAd: false,
        user: u,
      );

  factory _PostEntry.fromAd(AdModel a) => _PostEntry(
        uid: a.uid,
        name: a.name,
        username: '',
        photo: a.photoUrls.isNotEmpty ? a.photoUrls.first : '',
        age: a.age,
        bio: a.bio,
        published: a.published,
        blocked: false,
        pendingPublish: a.pendingPublish,
        isAd: true,
        ad: a,
      );
}

// ─── Post Tile ────────────────────────────────────────────────────────────────

class _PostTile extends StatelessWidget {
  final _PostEntry entry;
  const _PostTile({required this.entry});

  Future<void> _approve(BuildContext ctx) async {
    try {
      await FirebaseFirestore.instance
          .collection(entry.isAd ? 'ads' : 'users')
          .doc(entry.uid)
          .update({'published': true, 'pendingPublish': false});
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('تمت الموافقة ✓ — المنشور الآن مرئي للجميع'),
          backgroundColor: Color(0xFF22C55E),
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _reject(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: Text('رفض طلب نشر "${entry.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false),
              child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(d, true),
              child: const Text('رفض', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !ctx.mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection(entry.isAd ? 'ads' : 'users')
          .doc(entry.uid)
          .update({'pendingPublish': false});
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
          content: Text('تم رفض الطلب'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _message(BuildContext ctx) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    final ids = [myUid, entry.uid]..sort();
    final chatId = '${ids[0]}_${ids[1]}';
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => ChatScreen(
      chatId: chatId,
      myUid: myUid,
      friendUid: entry.uid,
      friendName: entry.name.isEmpty ? 'مستخدم' : entry.name,
      friendPhoto: entry.photo,
    )));
  }

  Future<void> _toggleBlock(BuildContext ctx) async {
    final newVal = !entry.blocked;
    try {
      await FirebaseFirestore.instance
          .collection(entry.isAd ? 'ads' : 'users')
          .doc(entry.uid)
          .update({'blocked': newVal});
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(newVal ? 'تم الحظر ✓' : 'تم إلغاء الحظر ✓'),
          backgroundColor: newVal ? Colors.red : const Color(0xFF25D366),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _delete(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('حذف "${entry.name}"؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child:
                  const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !ctx.mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection(entry.isAd ? 'ads' : 'users')
          .doc(entry.uid)
          .delete();
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _view(BuildContext ctx) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => entry.user != null
            ? PostDetailScreen.fromProfile(entry.user!)
            : PostDetailScreen.fromAd(entry.ad!),
      ),
    );
  }

  void _edit(BuildContext ctx) {
    final ad = entry.user != null
        ? AdModel(
            uid: entry.user!.uid,
            name: entry.user!.name,
            age: entry.user!.age,
            bio: entry.user!.bio,
            whatsapp: entry.user!.whatsapp,
            facebook: entry.user!.facebook,
            tiktok: entry.user!.tiktok,
            instagram: entry.user!.instagram,
            photoUrls: entry.user!.photoUrls,
            published: entry.user!.published,
          )
        : entry.ad!;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdEditSheet(
          ad: ad, collection: entry.isAd ? 'ads' : 'users'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: entry.blocked
            ? const Color(0xFFFFF0F0)
            : entry.pendingPublish
                ? const Color(0xFFF5F0FF)
                : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.blocked
              ? Colors.red.withValues(alpha: 0.4)
              : entry.pendingPublish
                  ? const Color(0xFF7C3AED).withValues(alpha: 0.5)
                  : const Color(0xFFFFCCE8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.pink.withValues(alpha: 0.06), blurRadius: 6)
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFF8D7E8),
              backgroundImage:
                  entry.photo.isNotEmpty ? NetworkImage(entry.photo) : null,
              child: entry.photo.isEmpty
                  ? Icon(
                      entry.isAd
                          ? Icons.campaign_rounded
                          : Icons.person,
                      color: const Color(0xFFE91E8C))
                  : null,
            ),
            // نقطة الحالة
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: entry.blocked
                      ? Colors.red
                      : entry.pendingPublish
                          ? const Color(0xFF7C3AED)
                          : entry.published
                              ? const Color(0xFF22C55E)
                              : Colors.grey[400],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                entry.name.isEmpty ? '(بدون اسم)' : entry.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: entry.blocked
                      ? Colors.red[700]
                      : const Color(0xFF3D0030),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // شارات الحالة
            if (entry.blocked)
              _Badge(label: 'محظور', color: Colors.red),
            if (!entry.blocked && entry.pendingPublish)
              _Badge(label: '🕐 طلب', color: const Color(0xFF7C3AED)),
            if (!entry.blocked && !entry.pendingPublish && entry.isAd)
              _Badge(label: 'إعلان', color: const Color(0xFF0284C7)),
            if (!entry.blocked && !entry.pendingPublish && !entry.isAd && entry.published)
              _Badge(label: 'منشور', color: const Color(0xFF22C55E)),
            if (!entry.blocked && !entry.pendingPublish && !entry.published && !entry.isAd)
              _Badge(label: 'مخفي', color: Colors.grey),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.username.isNotEmpty)
              Text('# ${entry.username}',
                  style: const TextStyle(
                      color: Color(0xFFE91E8C),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            Text('${entry.age > 0 ? entry.age : '?'} سنة',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: _ActionButtons(
          entry: entry,
          onView: () => _view(context),
          onEdit: () => _edit(context),
          onBlock: () => _toggleBlock(context),
          onDelete: () => _delete(context),
          onApprove: () => _approve(context),
          onReject: () => _reject(context),
          onMessage: () => _message(context),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final _PostEntry entry;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onBlock;
  final VoidCallback onDelete;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onMessage;
  const _ActionButtons({
    required this.entry,
    required this.onView,
    required this.onEdit,
    required this.onBlock,
    required this.onDelete,
    required this.onApprove,
    required this.onReject,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // عرض
        _MiniBtn(
            icon: Icons.visibility_rounded,
            color: const Color(0xFF7C3AED),
            tooltip: 'عرض',
            onTap: onView),
        // تعديل
        _MiniBtn(
            icon: Icons.edit_rounded,
            color: const Color(0xFF0284C7),
            tooltip: 'تعديل',
            onTap: onEdit),
        // ── أزرار خاصة بطلبات النشر ───
        if (entry.pendingPublish) ...[
          _MiniBtn(
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF22C55E),
              tooltip: 'موافقة',
              onTap: onApprove),
          _MiniBtn(
              icon: Icons.cancel_rounded,
              color: Colors.orange,
              tooltip: 'رفض',
              onTap: onReject),
          _MiniBtn(
              icon: Icons.chat_bubble_outline_rounded,
              color: const Color(0xFFE91E8C),
              tooltip: 'مراسلة',
              onTap: onMessage),
        ] else ...[
          // حظر / إلغاء حظر (مستخدمون فقط)
          if (!entry.isAd)
            _MiniBtn(
                icon: entry.blocked
                    ? Icons.lock_open_rounded
                    : Icons.block_rounded,
                color: entry.blocked ? const Color(0xFF22C55E) : Colors.red,
                tooltip: entry.blocked ? 'إلغاء الحظر' : 'حظر',
                onTap: onBlock),
          // حذف
          _MiniBtn(
              icon: Icons.delete_rounded,
              color: Colors.red,
              tooltip: 'حذف',
              onTap: onDelete),
        ],
      ],
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _MiniBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border:
                Border.all(color: color.withValues(alpha: 0.4), width: 1),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

class _FChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;
  const _FChip(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE91E8C)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFFE91E8C)
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
            )),
      ),
    );
  }
}

class _CountHeader extends StatelessWidget {
  final int shown;
  final int total;
  const _CountHeader({required this.shown, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('$shown منشور',
              style: const TextStyle(
                  color: Color(0xFFE91E8C),
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const Spacer(),
          Text('الكل: $total',
              style:
                  const TextStyle(color: Color(0xFFBB8899), fontSize: 12)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _SectionHeader(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color)),
            Text(subtitle,
                style: const TextStyle(
                    color: Color(0xFFBB8899), fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

// ─── Admin Profile Tab ───────────────────────────────────────────────────────

class _AdminProfileTab extends StatefulWidget {
  const _AdminProfileTab();

  @override
  State<_AdminProfileTab> createState() => _AdminProfileTabState();
}

class _AdminProfileTabState extends State<_AdminProfileTab> {
  final _nameCtrl = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  bool _uploading = false;
  String _photoUrl = '';

  final _doc = FirebaseFirestore.instance
      .collection('config')
      .doc('admin_profile');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final snap = await _doc.get();
    final data = snap.data() ?? {};
    _nameCtrl.text = (data['name'] as String?)?.isEmpty == false
        ? data['name'] as String
        : 'Admin';
    _photoUrl = data['photoUrl'] as String? ?? '';
    setState(() => _loaded = true);
  }

  Future<void> _pickAndUploadPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      // اسم فريد بالـ timestamp لضمان URL جديد في كل رفع
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance.ref('config/admin_photo_$ts.jpg');
      final task = await ref.putData(
          bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await task.ref.getDownloadURL();
      if (mounted) setState(() { _photoUrl = url; _uploading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل الرفع: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final name = _nameCtrl.text.trim().isEmpty
          ? 'Admin'
          : _nameCtrl.text.trim();
      await _doc.set({
        'name': name,
        'photoUrl': _photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم الحفظ ✓'),
              backgroundColor: Color(0xFF22C55E)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFE91E8C)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),

          // ── صورة الأدمن ────────────────────────────────────────────
          Text('صورة الأدمن',
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),

          Stack(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFFE91E8C), width: 3),
                  color: const Color(0xFFFFCCE8),
                ),
                child: ClipOval(
                  child: _uploading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFE91E8C),
                              strokeWidth: 2))
                      : _photoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _photoUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: Color(0xFFE91E8C),
                                  size: 46),
                              errorWidget: (_, _, _) => const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: Color(0xFFE91E8C),
                                  size: 46),
                            )
                          : const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Color(0xFFE91E8C),
                              size: 46),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _uploading ? null : _pickAndUploadPhoto,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E8C),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 17),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── اسم الأدمن ─────────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: Text('اسم الأدمن (يظهر في الرسائل)',
                style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3D0030)),
            decoration: InputDecoration(
              hintText: 'Admin',
              prefixIcon: const Icon(Icons.badge_rounded,
                  color: Color(0xFFE91E8C)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFE91E8C), width: 2),
              ),
              filled: true,
              fillColor: const Color(0xFFFFF5FA),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),

          const SizedBox(height: 20),

          // ── معلومة ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Color(0xFF7C3AED), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'الاسم والصورة يظهران عند مراسلة المستخدمين من حساب الأدمن',
                    style: TextStyle(
                        color: Color(0xFF4C1D95),
                        fontSize: 12,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── زر الحفظ ──────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_rounded),
            label: const Text('حفظ الملف',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E8C),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Ad Edit Sheet ────────────────────────────────────────────────────────────

class AdEditSheet extends StatefulWidget {
  final AdModel ad;
  final String collection;

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
    _photos    = List<String>.from(widget.ad.photoUrls);
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

  Future<void> _addPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('فشل رفع الصورة: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _photoLoading = false);
    }
  }

  Future<void> _removePhoto(int i) async {
    try {
      await FirebaseStorage.instance.refFromURL(_photos[i]).delete();
    } catch (_) {}
    setState(() => _photos.removeAt(i));
  }

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

  Future<void> _deleteRecord() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child:
                  const Text('حذف', style: TextStyle(color: Colors.red))),
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
            const SizedBox(height: 10),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Text('تعديل المنشور',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.visibility_rounded,
                        color: Color(0xFF7C3AED)),
                    onPressed: _viewPost,
                    tooltip: 'عرض',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, color: Colors.red),
                    onPressed: _deleteRecord,
                    tooltip: 'حذف',
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 16),
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                          Icons.add_photo_alternate_rounded,
                                          color: Color(0xFFE91E8C),
                                          size: 30),
                                      SizedBox(height: 6),
                                      Text('إضافة',
                                          style: TextStyle(
                                              color: Color(0xFFE91E8C),
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight.w600)),
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
                  _Field(ctrl: _name, label: 'الاسم', icon: Icons.person_outline),
                  _Field(ctrl: _age, label: 'العمر', icon: Icons.cake_outlined,
                      keyboardType: TextInputType.number),
                  _Field(ctrl: _bio, label: 'البيو', icon: Icons.notes_rounded,
                      maxLines: 3),
                  _Field(ctrl: _whatsapp, label: 'واتساب', icon: Icons.chat_rounded,
                      iconColor: const Color(0xFF25D366)),
                  _Field(ctrl: _facebook, label: 'فيسبوك',
                      icon: Icons.facebook_rounded,
                      iconColor: const Color(0xFF1877F2)),
                  _Field(ctrl: _tiktok, label: 'تيكتوك',
                      icon: Icons.music_note_rounded, iconColor: Colors.black),
                  _Field(ctrl: _instagram, label: 'انستغرام',
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
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
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
          prefixIcon: Icon(icon,
              color: iconColor ?? const Color(0xFFE91E8C), size: 20),
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

// ─── Social Field Helper ──────────────────────────────────────────────────────

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
            Icon(icon, color: color, size: 17),
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
              hintStyle:
                  const TextStyle(color: Colors.grey, fontSize: 12),
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
