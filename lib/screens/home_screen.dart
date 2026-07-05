import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../utils/web_video.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad_model.dart';
import '../models/feed_item.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import 'ad_screen.dart';
import 'admin_screen.dart' show isAdminUser, initAdminState, resetAdminState, AdminScreen;
import 'auth_screen.dart';
import 'friends_screen.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _usernameLookupLoading = false;
  StreamSubscription<QuerySnapshot>? _inboxSub;
  StreamSubscription<User?>? _authRestoreSub;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _listenInbox();
    _restoreAdminState();
  }

  /// On web, Firebase Auth restores the session asynchronously.
  /// This waits for auth, then reads admin_sessions from Firestore.
  void _restoreAdminState() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _checkAndSetAdmin();
    } else {
      _authRestoreSub = FirebaseAuth.instance.authStateChanges().listen((u) {
        if (u != null && mounted) {
          _authRestoreSub?.cancel();
          _authRestoreSub = null;
          _checkAndSetAdmin();
          _listenInbox(); // also start inbox listener now that auth is ready
        }
      });
    }
  }

  Future<void> _checkAndSetAdmin() async {
    if (isAdminUser()) {
      if (mounted) setState(() {});
      return;
    }
    await initAdminState();
    if (mounted) setState(() {});
  }

  void _listenInbox() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || FirebaseAuth.instance.currentUser?.isAnonymous == true) {
      return;
    }
    _startTime = DateTime.now();
    _inboxSub = FirebaseFirestore.instance
        .collection('inbox')
        .doc(uid)
        .collection('messages')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snap) {
          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final data = change.doc.data() as Map<String, dynamic>;
            final ts = (data['createdAt'] as Timestamp?)?.toDate();
            if (ts == null || ts.isBefore(_startTime!)) continue;
            final type = data['type'] as String? ?? '';
            final fromName = data['fromName'] as String? ?? 'مستخدم';
            final String title, body;
            if (type == 'message') {
              title = fromName;
              body = data['text'] as String? ?? '';
            } else if (type == 'friend_request') {
              title = 'طلب صداقة جديد';
              body = '$fromName أرسل لك طلب صداقة';
            } else {
              title = fromName;
              body = data['text'] as String? ?? '';
            }
            NotificationService().show(title: title, body: body);
          }
        });
  }

  @override
  void dispose() {
    _inboxSub?.cancel();
    _authRestoreSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FeedItem> _filter(List<FeedItem> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((item) {
      if (item.isAd) {
        final a = item.ad!;
        return a.name.toLowerCase().contains(q) ||
            a.bio.toLowerCase().contains(q) ||
            a.age.toString() == q;
      } else {
        final u = item.profile!;
        return u.name.toLowerCase().contains(q) ||
            u.bio.toLowerCase().contains(q) ||
            u.age.toString() == q ||
            u.username.toLowerCase().contains(q);
      }
    }).toList();
  }

  bool get _isUsernameQuery {
    final q = _query.trim();
    return q.length >= 4 && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(q);
  }

  Future<void> _searchByUserId() async {
    final q = _query.trim();
    if (q.isEmpty || _usernameLookupLoading) return;
    setState(() => _usernameLookupLoading = true);
    try {
      final user = await FirebaseService().searchByUsername(q);
      if (!mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا يوجد مستخدم بهذا المعرّف: # $q'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen.fromProfile(user)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _usernameLookupLoading = false);
    }
  }

  Widget _buildNavBar(BuildContext _) {
    final isGuest =
        FirebaseAuth.instance.currentUser?.isAnonymous == true &&
        !isAdminUser();

    if (isGuest) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                resetAdminState();
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              },
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text(
                'دخول / تسجيل',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E8C),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: const Color(0xFFE91E8C).withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        _BottomNavBtn(
          icon: Icons.group_outlined,
          label: 'الأصدقاء',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FriendsScreen()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdScreen()),
            ),
            icon: const Icon(Icons.campaign_rounded, size: 18),
            label: const Text(
              'إضافة إعلان',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.35),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _BottomNavBtn(
          icon: Icons.person_outline_rounded,
          label: 'ملفي',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
        ),
        if (isAdminUser()) ...[
          const SizedBox(width: 10),
          _BottomNavBtn(
            icon: Icons.admin_panel_settings_rounded,
            label: 'Admin',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminScreen()),
            ),
          ),
        ],
      ],
    );
  }

  Future<bool> _onWillPop() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الخروج من التطبيق'),
        content: const Text('هل تريد الخروج من التطبيق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لا', style: TextStyle(color: Color(0xFFE91E8C))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E8C),
              foregroundColor: Colors.white,
            ),
            child: const Text('نعم، خروج'),
          ),
        ],
      ),
    );
    return exit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _onWillPop();
        if (shouldExit && !kIsWeb) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF0F7),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF0F7),
              border: Border(
                top: BorderSide(color: Color(0xFFFFCCE8), width: 1),
              ),
            ),
            child: _buildNavBar(context),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF5FA), Color(0xFFFFF0F7)],
                ),
              ),
              child: CustomScrollView(
                slivers: [
                  // مسافة الـ status bar
                  const SliverToBoxAdapter(
                    child: SafeArea(bottom: false, child: SizedBox.shrink()),
                  ),

                  // ── Banner Ads ───────────────────────────────────────────
                  const SliverToBoxAdapter(child: _BannerAds()),

                  // ── Action buttons (هدية / اشتراك / اسناب) ─────────────
                  const SliverToBoxAdapter(child: _ActionBar()),

                  // ── Social links ─────────────────────────────────────────
                  const SliverToBoxAdapter(child: _SocialBar()),

                  // ── Search bar ───────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _query.isNotEmpty
                                ? const Color(0xFFE91E8C)
                                : const Color(0xFFFFB3D9),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFE91E8C,
                              ).withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: Color(0xFF3D0030),
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'ابحث بالاسم أو البيو...',
                            hintStyle: const TextStyle(
                              color: Color(0xFFBB8899),
                              fontSize: 13,
                            ),
                            prefixIcon: _query.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Color(0xFFE91E8C),
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _query = '');
                                    },
                                  )
                                : null,
                            suffixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFFE91E8C),
                              size: 22,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                    ),
                  ),

                  // ── Username search chip ─────────────────────────────────
                  if (_isUsernameQuery)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: GestureDetector(
                          onTap: _searchByUserId,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFE91E8C,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFFE91E8C,
                                ).withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                _usernameLookupLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFE91E8C),
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.tag_rounded,
                                        color: Color(0xFFE91E8C),
                                        size: 18,
                                      ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'البحث بالمعرّف: # ${_query.trim()}',
                                    style: const TextStyle(
                                      color: Color(0xFFE91E8C),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Color(0xFFE91E8C),
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Combined feed (ads + profiles) ───────────────────────
                  StreamBuilder<List<FeedItem>>(
                    stream: FirebaseService().combinedFeedStream(),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFE91E8C),
                            ),
                          ),
                        );
                      }
                      if (snap.hasError) {
                        return SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'خطأ: ${snap.error}',
                              style: const TextStyle(color: Color(0xFFBB8899)),
                            ),
                          ),
                        );
                      }

                      final all = snap.data ?? [];
                      final items = _filter(all);

                      if (all.isEmpty) {
                        return SliverFillRemaining(child: _emptyState());
                      }

                      if (items.isEmpty) {
                        return SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 68,
                                  color: Colors.pink.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'لا نتائج لـ "$_query"',
                                  style: const TextStyle(
                                    color: Color(0xFFBB8899),
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.72,
                              ),
                          delegate: SliverChildBuilderDelegate((ctx, i) {
                            final item = items[i];
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => item.isAd
                                      ? PostDetailScreen.fromAd(item.ad!)
                                      : PostDetailScreen.fromProfile(
                                          item.profile!,
                                        ),
                                ),
                              ),
                              child: item.isAd
                                  ? _AdCard(ad: item.ad!)
                                  : _ProfileCard(user: item.profile!),
                            );
                          }, childCount: items.length),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

          ], // Stack children
        ), // Stack
      ), // Scaffold
    ); // PopScope
  }

  Widget _emptyState() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/natalie/frasha.jpeg', fit: BoxFit.cover),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87],
            ),
          ),
        ),
        const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 80, color: Colors.white38),
            SizedBox(height: 20),
            Text(
              'لا يوجد منشورات بعد',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'أضف إعلانك الآن ليظهر هنا',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Ad Card — identical look to Profile Card ────────────────────────────────

class _AdCard extends StatefulWidget {
  final AdModel ad;
  const _AdCard({required this.ad});
  @override
  State<_AdCard> createState() => _AdCardState();
}

class _AdCardState extends State<_AdCard> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _openWhatsapp(String p) async {
    final c = p.replaceAll(RegExp(r'[^\d+]'), '');
    await launchUrl(
      Uri.parse('https://wa.me/$c'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openLink(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

  Future<void> _openTiktok(String u) async {
    if (u.isEmpty) return;
    await _openLink('https://tiktok.com/@${_username(u)}');
  }

  Future<void> _openInstagram(String u) async {
    if (u.isEmpty) return;
    final name = _username(u);
    try {
      await launchUrl(
        Uri.parse('instagram://user?username=$name'),
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (_) {
      await _openLink('https://instagram.com/$name');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final photos = ad.photoUrls;
    final hasSocial =
        ad.whatsapp.isNotEmpty ||
        ad.facebook.isNotEmpty ||
        ad.tiktok.isNotEmpty ||
        ad.instagram.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E8C).withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photos.isEmpty
                      ? Container(
                          color: const Color(0xFFF8D7E8),
                          child: const Icon(
                            Icons.person,
                            size: 50,
                            color: Color(0xFFE91E8C),
                          ),
                        )
                      : PageView.builder(
                          controller: _pageCtrl,
                          onPageChanged: (i) =>
                              setState(() => _currentPage = i),
                          itemCount: photos.length,
                          itemBuilder: (ctx, i) => CachedNetworkImage(
                            imageUrl: photos[i],
                            fit: BoxFit.cover,
                            placeholder: (ctx, url) => Container(
                              color: const Color(0xFFF8D7E8),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFE91E8C),
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (ctx, url, e) => Container(
                              color: const Color(0xFFF8D7E8),
                              child: const Icon(
                                Icons.broken_image,
                                size: 36,
                                color: Color(0xFFE91E8C),
                              ),
                            ),
                          ),
                        ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.45, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.88),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (photos.length > 1)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          photos.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: _currentPage == i ? 14 : 4,
                            height: 3,
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
                  Positioned(
                    bottom: 10,
                    left: 8,
                    right: 8,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ad.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 8),
                                  ],
                                ),
                              ),
                              if (ad.bio.isNotEmpty)
                                Text(
                                  ad.bio,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    fontSize: 11,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE91E8C),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${ad.age} سنة',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (hasSocial)
              Container(
                height: 38,
                color: const Color(0xFF2D0022),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (ad.whatsapp.isNotEmpty)
                      _MiniBtn(
                        icon: Icons.chat_rounded,
                        color: const Color(0xFF25D366),
                        onTap: () => _openWhatsapp(ad.whatsapp),
                      ),
                    if (ad.facebook.isNotEmpty)
                      _MiniBtn(
                        icon: Icons.facebook_rounded,
                        color: const Color(0xFF1877F2),
                        onTap: () => _openLink(ad.facebook),
                      ),
                    if (ad.tiktok.isNotEmpty)
                      _MiniBtn(
                        icon: Icons.music_note_rounded,
                        color: Colors.white,
                        onTap: () => _openTiktok(ad.tiktok),
                      ),
                    if (ad.instagram.isNotEmpty)
                      _MiniBtn(
                        icon: Icons.camera_alt_rounded,
                        color: const Color(0xFFE1306C),
                        onTap: () => _openInstagram(ad.instagram),
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

// ─── Profile Card ─────────────────────────────────────────────────────────────

class _ProfileCard extends StatefulWidget {
  final UserModel user;
  const _ProfileCard({required this.user});

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _openWhatsapp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    await launchUrl(
      Uri.parse('https://wa.me/$clean'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openLink(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

  Future<void> _openTiktok(String u) async {
    if (u.isEmpty) return;
    await _openLink('https://tiktok.com/@${_username(u)}');
  }

  Future<void> _openInstagram(String u) async {
    if (u.isEmpty) return;
    final name = _username(u);
    try {
      await launchUrl(
        Uri.parse('instagram://user?username=$name'),
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (_) {
      await _openLink('https://instagram.com/$name');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final photos = user.photoUrls;
    final hasSocial =
        user.whatsapp.isNotEmpty ||
        user.facebook.isNotEmpty ||
        user.tiktok.isNotEmpty ||
        user.instagram.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E8C).withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photos.isEmpty
                      ? Container(
                          color: const Color(0xFFF8D7E8),
                          child: const Icon(
                            Icons.person,
                            size: 50,
                            color: Color(0xFFE91E8C),
                          ),
                        )
                      : PageView.builder(
                          controller: _pageCtrl,
                          onPageChanged: (i) =>
                              setState(() => _currentPage = i),
                          itemCount: photos.length,
                          itemBuilder: (ctx, i) => CachedNetworkImage(
                            imageUrl: photos[i],
                            fit: BoxFit.cover,
                            placeholder: (ctx, url) => Container(
                              color: const Color(0xFFF8D7E8),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFE91E8C),
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (ctx, url, e) => Container(
                              color: const Color(0xFFF8D7E8),
                              child: const Icon(
                                Icons.broken_image,
                                size: 36,
                                color: Color(0xFFE91E8C),
                              ),
                            ),
                          ),
                        ),

                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.45, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.88),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (photos.length > 1)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(photos.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: _currentPage == i ? 14 : 4,
                            height: 3,
                            decoration: BoxDecoration(
                              color: _currentPage == i
                                  ? const Color(0xFFE91E8C)
                                  : Colors.white54,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    ),

                  Positioned(
                    bottom: 10,
                    left: 8,
                    right: 8,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 8),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE91E8C),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${user.age} سنة',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (hasSocial)
              Container(
                height: 38,
                color: const Color(0xFF2D0022),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (user.whatsapp.isNotEmpty)
                      _MiniBtn(
                        icon: Icons.chat_rounded,
                        color: const Color(0xFF25D366),
                        onTap: () => _openWhatsapp(user.whatsapp),
                      ),
                    if (user.facebook.isNotEmpty)
                      _MiniBtn(
                        icon: Icons.facebook_rounded,
                        color: const Color(0xFF1877F2),
                        onTap: () => _openLink(user.facebook),
                      ),
                    if (user.tiktok.isNotEmpty)
                      _MiniBtn(
                        icon: Icons.music_note_rounded,
                        color: Colors.white,
                        onTap: () => _openTiktok(user.tiktok),
                      ),
                    if (user.instagram.isNotEmpty)
                      _MiniBtn(
                        icon: Icons.camera_alt_rounded,
                        color: const Color(0xFFE1306C),
                        onTap: () => _openInstagram(user.instagram),
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

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MiniBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

// ─── Bottom Nav Button ────────────────────────────────────────────────────────

class _BottomNavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BottomNavBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE0F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFB3D9), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFE91E8C), size: 20),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFE91E8C),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action Bar (هداية / اشتراك / اسناب) ────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar();

  static Future<void> _open(BuildContext ctx, String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('لم يُضف الرابط بعد')));
      return;
    }
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('config')
          .doc('social_links')
          .snapshots(),
      builder: (ctx, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final giftUrl = (data['gift'] as String? ?? '').trim();
        final subUrl = (data['subscription'] as String? ?? '').trim();
        final snapchatUrl = (data['snapchat'] as String? ?? '').trim();

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  label: 'هدية',
                  icon: Icons.redeem_rounded,
                  color: const Color(0xFFE91E8C),
                  onTap: () => _open(ctx, giftUrl),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  label: 'اشتراك',
                  icon: Icons.stars_rounded,
                  color: const Color(0xFF7C3AED),
                  onTap: () => _open(ctx, subUrl),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  label: 'مجموعة واتساب\nامريكة',
                  icon: Icons.chat_rounded,
                  flag: '🇺🇸',
                  color: const Color(0xFF25D366),
                  onTap: () => _open(ctx, snapchatUrl),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? flag;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.flag,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.40), width: 1.3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (flag != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 3),
                  Text(flag!, style: const TextStyle(fontSize: 18)),
                ],
              )
            else
              Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Social Bar ───────────────────────────────────────────────────────────────

class _SocialBar extends StatelessWidget {
  const _SocialBar();

  static Future<void> _open(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('config')
          .doc('social_links')
          .snapshots(),
      builder: (ctx, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final wa = (data['whatsapp'] as String? ?? '').trim();
        final fb = (data['facebook'] as String? ?? '').trim();
        final tt = (data['tiktok'] as String? ?? '').trim();
        final ig = (data['instagram'] as String? ?? '').trim();

        final buttons = <Widget>[
          if (wa.isNotEmpty)
            _SocialBtn(
              label: 'واتساب',
              color: const Color(0xFF25D366),
              icon: Icons.chat_rounded,
              onTap: () => _open('https://wa.me/$wa'),
            ),
          if (fb.isNotEmpty)
            _SocialBtn(
              label: 'فيسبوك',
              color: const Color(0xFF1877F2),
              icon: Icons.facebook_rounded,
              onTap: () => _open(fb),
            ),
          if (tt.isNotEmpty)
            _SocialBtn(
              label: 'تيكتوك',
              color: Colors.black,
              icon: Icons.music_note_rounded,
              onTap: () => _open(tt),
            ),
          if (ig.isNotEmpty)
            _SocialBtn(
              label: 'انستغرام',
              color: const Color(0xFFE1306C),
              icon: Icons.camera_alt_rounded,
              onTap: () => _open(ig),
            ),
        ];

        if (buttons.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: buttons,
          ),
        );
      },
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _SocialBtn({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Banner Ads ───────────────────────────────────────────────────────────────

class _BannerAds extends StatefulWidget {
  const _BannerAds();

  @override
  State<_BannerAds> createState() => _BannerAdsState();
}

typedef _BannerItem = ({String url, int duration});

class _BannerAdsState extends State<_BannerAds> {
  final PageController _ctrl = PageController();
  Timer? _timer;
  StreamSubscription<QuerySnapshot>? _sub;

  int _current = 0;
  List<_BannerItem> _items = [];
  bool _loading = true;

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return 0;
  }

  static bool _isVideo(String url) {
    final u = url.toLowerCase();
    return u.contains('.mp4') ||
        u.contains('.mov') ||
        u.contains('.webm') ||
        u.contains('video%20') ||
        u.contains('%20video');
  }

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance
        .collection('banner_ads')
        .where('active', isEqualTo: true)
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            final docs = [...snap.docs]
              ..sort((a, b) => _toInt((a.data())['order'])
                  .compareTo(_toInt((b.data())['order'])));

            final items = docs
                .map((d) {
                  final url = (d.data()['imageUrl'] as String?) ?? '';
                  final dur = _toInt(d.data()['duration']) > 0
                      ? _toInt(d.data()['duration'])
                      : 5; // الافتراضي 5 ثواني
                  return (url: url, duration: dur);
                })
                .where((item) => item.url.isNotEmpty)
                .toList();

            setState(() {
              _items = items;
              _loading = false;
            });
            _scheduleNext();
          },
          onError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        );
  }

  void _scheduleNext() {
    _timer?.cancel();
    _timer = null;
    if (_items.length <= 1) return;
    final secs = _items.isNotEmpty ? _items[_current].duration : 5;
    _timer = Timer(Duration(seconds: secs), () {
      if (!mounted) return;
      final next = (_current + 1) % _items.length;
      if (_ctrl.hasClients) {
        _ctrl.animateToPage(next,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut);
      }
      // سيُستدعى _scheduleNext تلقائياً عبر onPageChanged
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFE91E8C), strokeWidth: 2),
        ),
      );
    }

    if (_items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 180,
          child: Stack(
            children: [
              PageView.builder(
                controller: _ctrl,
                itemCount: _items.length,
                onPageChanged: (i) {
                  setState(() => _current = i);
                  _scheduleNext(); // كل بنر يستخدم مدته الخاصة
                },
                itemBuilder: (ctx, i) {
                  final url = _items[i].url;
                  if (_isVideo(url)) {
                    return _BannerVideoItem(url: url);
                  }
                  return CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 180,
                    placeholder: (ctx, url) => Container(
                      color: const Color(0xFF2D0022),
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFE91E8C), strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (ctx, url, e) => Container(
                      color: const Color(0xFF2D0022),
                      child: const Icon(Icons.broken_image,
                          color: Colors.white24, size: 40),
                    ),
                  );
                },
              ),

              // ── نقاط التنقل ──────────────────────────────────────────
              if (_items.length > 1)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_items.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _current == i ? 20 : 6,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _current == i
                              ? const Color(0xFFE91E8C)
                              : Colors.white54,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Banner Video Item ────────────────────────────────────────────────────────

class _BannerVideoItem extends StatefulWidget {
  final String url;
  const _BannerVideoItem({required this.url});

  @override
  State<_BannerVideoItem> createState() => _BannerVideoItemState();
}

class _BannerVideoItemState extends State<_BannerVideoItem>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _ctrl;
  bool _ready = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _ctrl = ctrl;
      await ctrl.initialize();
      ctrl.setLooping(true);
      ctrl.setVolume(0); // مكتوم دائماً في البنر
      await ctrl.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // إذا فشل التحميل يظهر placeholder
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // على الويب: استخدم <video> native مباشرة (يتجاوز قيود CORS في video_player)
    if (kIsWeb) {
      return buildNativeWebVideo(widget.url);
    }

    if (!_ready || _ctrl == null) {
      return Container(
        color: const Color(0xFF2D0022),
        child: const Center(
          child: CircularProgressIndicator(
              color: Color(0xFFE91E8C), strokeWidth: 2),
        ),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _ctrl!.value.size.width,
          height: _ctrl!.value.size.height,
          child: VideoPlayer(_ctrl!),
        ),
      ),
    );
  }
}

