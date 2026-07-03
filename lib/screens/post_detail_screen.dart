import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad_model.dart';
import '../models/user_model.dart';
import 'admin_screen.dart';
import 'chat_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final List<String> photos;
  final String name;
  final int age;
  final String bio;
  final String whatsapp;
  final String facebook;
  final String tiktok;
  final String instagram;
  final String postId;
  final String ownerUid; // UID صاحب الإعلان (للأدمن)

  const PostDetailScreen({
    super.key,
    required this.photos,
    required this.name,
    required this.age,
    required this.bio,
    required this.whatsapp,
    required this.facebook,
    required this.tiktok,
    required this.instagram,
    required this.postId,
    required this.ownerUid,
  });

  factory PostDetailScreen.fromAd(AdModel ad) => PostDetailScreen(
        photos: ad.photoUrls,
        name: ad.name,
        age: ad.age,
        bio: ad.bio,
        whatsapp: ad.whatsapp,
        facebook: ad.facebook,
        tiktok: ad.tiktok,
        instagram: ad.instagram,
        postId: 'ad_${ad.uid}',
        ownerUid: ad.uid,
      );

  factory PostDetailScreen.fromProfile(UserModel user) => PostDetailScreen(
        photos: user.photoUrls,
        name: user.name,
        age: user.age,
        bio: user.bio,
        whatsapp: user.whatsapp,
        facebook: user.facebook,
        tiktok: user.tiktok,
        instagram: user.instagram,
        postId: 'profile_${user.uid}',
        ownerUid: user.uid,
      );

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _isAnon =>
      FirebaseAuth.instance.currentUser?.isAnonymous ?? true;

  DocumentReference get _likesRef =>
      _db.collection('post_likes').doc(widget.postId);

  Future<void> _toggleLike(List likedBy) async {
    if (_isAnon || _uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل دخولاً لتتمكن من الإعجاب')),
      );
      return;
    }
    final liked = likedBy.contains(_uid);
    await _likesRef.set({
      'likedBy': liked
          ? FieldValue.arrayRemove([_uid])
          : FieldValue.arrayUnion([_uid]),
    }, SetOptions(merge: true));
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    await _openUrl('https://wa.me/$clean');
  }

  String _username(String u) {
    if (u.startsWith('http')) {
      final uri = Uri.tryParse(u);
      if (uri != null) {
        final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (seg.isNotEmpty) return seg.first.replaceAll('@', '');
      }
    }
    return u.replaceAll('@', '').trim();
  }

  Future<void> _openTikTok(String u) async {
    if (u.isEmpty) return;
    await _openUrl('https://tiktok.com/@${_username(u)}');
  }

  Future<void> _openInstagram(String u) async {
    if (u.isEmpty) return;
    final name = _username(u);
    try {
      await launchUrl(Uri.parse('instagram://user?username=$name'),
          mode: LaunchMode.externalNonBrowserApplication);
    } catch (_) {
      await launchUrl(Uri.parse('https://instagram.com/$name'),
          mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5FA),
      body: Column(
        children: [
          // ── صور المنشور (PageView حر من أي scroll عمودي) ──────────
          SizedBox(
            height: screenH * 0.58,
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.photos.isEmpty
                    ? Container(
                        color: const Color(0xFFF8D7E8),
                        child: const Icon(Icons.person,
                            size: 80, color: Color(0xFFE91E8C)),
                      )
                    : PageView.builder(
                        controller: _pageCtrl,
                        physics: const BouncingScrollPhysics(),
                        itemCount: widget.photos.length,
                        onPageChanged: (i) =>
                            setState(() => _currentPage = i),
                        itemBuilder: (ctx, i) => CachedNetworkImage(
                          imageUrl: widget.photos[i],
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Container(
                            color: const Color(0xFFF8D7E8),
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFFE91E8C)),
                            ),
                          ),
                          errorWidget: (ctx, url, e) => Container(
                            color: const Color(0xFFF8D7E8),
                            child: const Icon(Icons.broken_image,
                                size: 60, color: Color(0xFFE91E8C)),
                          ),
                        ),
                      ),

                // تدرج أسفل الصورة
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.25),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // زر الرجوع
                Positioned(
                  top: topPad + 8,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),

                // زر تعديل الأدمن
                if (isAdminUser())
                  Positioned(
                    top: topPad + 8,
                    left: 12,
                    child: GestureDetector(
                      onTap: () {
                        final ad = AdModel(
                          uid: widget.ownerUid,
                          name: widget.name,
                          age: widget.age,
                          bio: widget.bio,
                          whatsapp: widget.whatsapp,
                          facebook: widget.facebook,
                          tiktok: widget.tiktok,
                          instagram: widget.instagram,
                          photoUrls: widget.photos,
                          published: true,
                        );
                        final col = widget.postId.startsWith('profile_')
                            ? 'users'
                            : 'ads';
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) =>
                              AdEditSheet(ad: ad, collection: col),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('تعديل',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),

                // نقاط التنقل بين الصور
                if (widget.photos.length > 1)
                  Positioned(
                    top: topPad + 16,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        widget.photos.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentPage == i ? 18 : 5,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _currentPage == i
                                ? const Color(0xFFE91E8C)
                                : Colors.white54,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),

                // الاسم والعمر في أسفل الصورة
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          widget.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 12)
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E8C),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${widget.age} سنة',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── محتوى المنشور (scroll عمودي مستقل) ───────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, -3))
                  ],
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // مقبض
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCCE8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── زر الصداقة / المراسلة ─────────────────────────
                  _FriendStatusButton(
                    ownerUid: widget.ownerUid,
                    ownerName: widget.name,
                    ownerPhoto: widget.photos.firstOrNull ?? '',
                  ),
                  const SizedBox(height: 8),

                  // البيو
                  if (widget.bio.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        widget.bio,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF3D0030),
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── أزرار السوشيال ميديا ───────────────────────────
                  if (widget.whatsapp.isNotEmpty ||
                      widget.facebook.isNotEmpty ||
                      widget.tiktok.isNotEmpty ||
                      widget.instagram.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('تواصل معي',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          if (widget.whatsapp.isNotEmpty)
                            Expanded(
                              child: _SocialFullBtn(
                                label: 'واتساب',
                                color: const Color(0xFF25D366),
                                icon: Icons.chat_rounded,
                                onTap: () => _openWhatsApp(widget.whatsapp),
                              ),
                            ),
                          if (widget.whatsapp.isNotEmpty &&
                              (widget.facebook.isNotEmpty ||
                                  widget.tiktok.isNotEmpty ||
                                  widget.instagram.isNotEmpty))
                            const SizedBox(width: 8),
                          if (widget.facebook.isNotEmpty)
                            Expanded(
                              child: _SocialFullBtn(
                                label: 'فيسبوك',
                                color: const Color(0xFF1877F2),
                                icon: Icons.facebook_rounded,
                                onTap: () => _openUrl(widget.facebook),
                              ),
                            ),
                          if (widget.facebook.isNotEmpty &&
                              (widget.tiktok.isNotEmpty ||
                                  widget.instagram.isNotEmpty))
                            const SizedBox(width: 8),
                          if (widget.tiktok.isNotEmpty)
                            Expanded(
                              child: _SocialFullBtn(
                                label: 'تيكتوك',
                                color: Colors.black,
                                icon: Icons.music_note_rounded,
                                onTap: () => _openTikTok(widget.tiktok),
                              ),
                            ),
                          if (widget.tiktok.isNotEmpty &&
                              widget.instagram.isNotEmpty)
                            const SizedBox(width: 8),
                          if (widget.instagram.isNotEmpty)
                            Expanded(
                              child: _SocialFullBtn(
                                label: 'انستغرام',
                                color: const Color(0xFFE1306C),
                                icon: Icons.camera_alt_rounded,
                                onTap: () =>
                                    _openInstagram(widget.instagram),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── زر القلب والتقييم ──────────────────────────────
                  const Divider(color: Color(0xFFFFEEF6), thickness: 1),
                  StreamBuilder<DocumentSnapshot>(
                    stream: _likesRef.snapshots(),
                    builder: (ctx, snap) {
                      final data =
                          snap.data?.data() as Map<String, dynamic>?;
                      final likedBy =
                          List.from(data?['likedBy'] as List? ?? []);
                      final count = likedBy.length;
                      final isLiked =
                          _uid != null && likedBy.contains(_uid);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => _toggleLike(likedBy),
                              child: AnimatedSwitcher(
                                duration:
                                    const Duration(milliseconds: 250),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(
                                        scale: anim, child: child),
                                child: Icon(
                                  isLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  key: ValueKey(isLiked),
                                  color: isLiked
                                      ? const Color(0xFFE91E8C)
                                      : Colors.grey[400],
                                  size: 36,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isLiked
                                    ? const Color(0xFFE91E8C)
                                    : Colors.grey[400],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'إعجاب',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}

// ─── Friend Status Button ─────────────────────────────────────────────────────

enum _FriendStatus { loading, none, friends }

class _FriendStatusButton extends StatefulWidget {
  final String ownerUid;
  final String ownerName;
  final String ownerPhoto;
  const _FriendStatusButton({
    required this.ownerUid,
    required this.ownerName,
    required this.ownerPhoto,
  });

  @override
  State<_FriendStatusButton> createState() => _FriendStatusButtonState();
}

class _FriendStatusButtonState extends State<_FriendStatusButton> {
  final _db = FirebaseFirestore.instance;
  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;
  bool get _isAnon =>
      FirebaseAuth.instance.currentUser?.isAnonymous ?? true;

  _FriendStatus _status = _FriendStatus.loading;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (_myUid == null || _isAnon || _myUid == widget.ownerUid) {
      _status = _FriendStatus.none;
      return;
    }
    _check();
  }

  Future<void> _check() async {
    try {
      final uid = _myUid!;
      final fSnap = await _db
          .collection('friends')
          .doc(uid)
          .collection('list')
          .doc(widget.ownerUid)
          .get();
      if (!mounted) return;
      setState(() =>
          _status = fSnap.exists ? _FriendStatus.friends : _FriendStatus.none);
    } catch (_) {
      if (mounted) setState(() => _status = _FriendStatus.none);
    }
  }

  String _chatId() {
    final s = [_myUid!, widget.ownerUid]..sort();
    return '${s[0]}_${s[1]}';
  }

  Future<void> _addFriend() async {
    setState(() => _busy = true);
    try {
      final uid = _myUid!;
      final chatId = _chatId();

      final myDoc = await _db.collection('users').doc(uid).get();
      final myName = (myDoc.data()?['name'] as String?) ?? 'مستخدم';
      final myPhoto =
          ((myDoc.data()?['photoUrls'] as List?)?.firstOrNull as String?) ?? '';

      final batch = _db.batch();

      // أضفني إلى قائمة صديق صاحب الملف
      batch.set(
        _db.collection('friends').doc(uid).collection('list').doc(widget.ownerUid),
        {
          'uid': widget.ownerUid,
          'name': widget.ownerName,
          'photoUrl': widget.ownerPhoto,
          'chatId': chatId,
          'addedAt': FieldValue.serverTimestamp(),
        },
      );

      // أضفه إلى قائمة أصدقائي
      batch.set(
        _db.collection('friends').doc(widget.ownerUid).collection('list').doc(uid),
        {
          'uid': uid,
          'name': myName,
          'photoUrl': myPhoto,
          'chatId': chatId,
          'addedAt': FieldValue.serverTimestamp(),
        },
      );

      // أنشئ/احتفظ بمحادثة مشتركة
      batch.set(
        _db.collection('chats').doc(chatId),
        {
          'participants': [uid, widget.ownerUid],
          'lastMessage': '',
          'lastAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // أرسل إشعاراً للمضاف
      batch.set(
        _db.collection('inbox').doc(widget.ownerUid).collection('messages').doc(),
        {
          'type': 'friend_added',
          'from': uid,
          'fromName': myName,
          'fromPhoto': myPhoto,
          'text': '$myName أضافك كصديق',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
      if (mounted) setState(() { _busy = false; _status = _FriendStatus.friends; });
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: const Color(0xFF7F1D1D)));
      }
    }
  }

  Future<void> _removeFriend() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزالة الصداقة', textDirection: TextDirection.rtl),
        content: Text('هل تريد إزالة ${widget.ownerName} من أصدقائك؟',
            textDirection: TextDirection.rtl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء',
                style: TextStyle(color: Color(0xFFE91E8C))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final uid = _myUid!;
      final batch = _db.batch();
      batch.delete(_db.collection('friends').doc(uid).collection('list').doc(widget.ownerUid));
      batch.delete(_db.collection('friends').doc(widget.ownerUid).collection('list').doc(uid));
      await batch.commit();
      if (mounted) setState(() { _busy = false; _status = _FriendStatus.none; });
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: const Color(0xFF7F1D1D)));
      }
    }
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: _chatId(),
          myUid: _myUid!,
          friendUid: widget.ownerUid,
          friendName: widget.ownerName,
          friendPhoto: widget.ownerPhoto,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // لا تظهر على ملفك الشخصي
    if (_myUid == null || _myUid == widget.ownerUid) {
      return const SizedBox.shrink();
    }

    // زائر: زر مراسلة مقفل مع رسالة
    if (_isAnon) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('سجّل دخولاً بـ Google للمراسلة والإضافة')),
            ),
            icon: const Icon(Icons.lock_outline_rounded,
                size: 18, color: Color(0xFFBB8899)),
            label: const Text('مراسلة',
                style: TextStyle(fontSize: 15, color: Color(0xFFBB8899))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFFCCE8), width: 1.3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      );
    }

    // مستخدم مسجل: زر مراسلة مباشرة + زر صداقة ثانوي
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── مراسلة مباشرة (دائماً ظاهر، لا تحتاج صداقة) ─────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _openChat,
              icon: const Icon(Icons.chat_bubble_rounded, size: 20),
              label: const Text('مراسلة',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E8C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                shadowColor:
                    const Color(0xFFE91E8C).withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
        // ── زر الصداقة ────────────────────────────────────────────
        _buildFriendRow(),
      ],
    );
  }

  Widget _buildFriendRow() {
    if (_status == _FriendStatus.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Center(
            child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: Color(0xFFE91E8C), strokeWidth: 2))),
      );
    }

    final bool isFriend = _status == _FriendStatus.friends;
    final IconData icon =
        isFriend ? Icons.person_remove_rounded : Icons.person_add_rounded;
    final String label = isFriend ? 'إزالة الصداقة' : 'إضافة صديق';
    final Color color = isFriend ? Colors.red : const Color(0xFFE91E8C);
    final VoidCallback? onTap =
        _busy ? null : (isFriend ? _removeFriend : _addFriend);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: SizedBox(
        height: 42,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: _busy
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color))
              : Icon(icon, size: 16, color: color),
          label: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color, width: 1.2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SocialFullBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _SocialFullBtn(
      {required this.label,
      required this.color,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.3),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
