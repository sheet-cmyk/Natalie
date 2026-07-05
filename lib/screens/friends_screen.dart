import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'post_detail_screen.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, authSnap) {
        final uid = authSnap.data?.uid ??
            FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          return const Scaffold(
            body: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFE91E8C))),
          );
        }
        return _FriendsBody(myUid: uid);
      },
    );
  }
}

class _FriendsBody extends StatefulWidget {
  final String myUid;
  const _FriendsBody({required this.myUid});

  @override
  State<_FriendsBody> createState() => _FriendsBodyState();
}

class _FriendsBodyState extends State<_FriendsBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF0F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF3D0030)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('الأصدقاء والرسائل',
            style: TextStyle(
                color: Color(0xFF3D0030), fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFFE91E8C),
          labelColor: const Color(0xFFE91E8C),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.people_rounded), text: 'الأصدقاء'),
            Tab(icon: Icon(Icons.chat_bubble_rounded), text: 'الرسائل'),
            Tab(icon: Icon(Icons.person_add_rounded), text: 'الطلبات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _FriendsList(uid: widget.myUid),
          _MessagesTab(myUid: widget.myUid),
          _RequestsTab(myUid: widget.myUid),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// تاب الأصدقاء
// ══════════════════════════════════════════════════════════════════════════════

class _FriendsList extends StatelessWidget {
  final String uid;
  const _FriendsList({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friends')
          .doc(uid)
          .collection('list')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFFE91E8C)));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyHint(
              icon: Icons.people_outline_rounded,
              msg: 'لا أصدقاء بعد\nأضف أصدقاء من صفحة ملفاتهم الشخصية');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final friendUid = docs[i].id;
            final username = (d['username'] as String?)?.isNotEmpty == true
                ? d['username'] as String
                : (d['name'] as String? ?? 'مستخدم');
            final photo = d['photoUrl'] as String? ?? '';
            final chatId =
                d['chatId'] as String? ?? _makeChatId(uid, friendUid);
            return _FriendTile(
                myUid: uid,
                uid: friendUid,
                username: username,
                photo: photo,
                chatId: chatId);
          },
        );
      },
    );
  }
}

class _FriendTile extends StatefulWidget {
  final String myUid;
  final String uid;
  final String username;
  final String photo;
  final String chatId;
  const _FriendTile(
      {required this.myUid,
      required this.uid,
      required this.username,
      required this.photo,
      required this.chatId});

  @override
  State<_FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends State<_FriendTile> {
  bool _removing = false;

  Future<void> _viewProfile() async {
    final db = FirebaseFirestore.instance;
    var doc = await db.collection('users').doc(widget.uid).get();
    if (!doc.exists) doc = await db.collection('ads').doc(widget.uid).get();
    if (!mounted || !doc.exists) return;
    final d = doc.data()!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          photos: List<String>.from(d['photoUrls'] as List? ?? []),
          name: d['name'] as String? ?? widget.username,
          age: (d['age'] as num?)?.toInt() ?? 0,
          bio: d['bio'] as String? ?? '',
          whatsapp: d['whatsapp'] as String? ?? '',
          facebook: d['facebook'] as String? ?? '',
          tiktok: d['tiktok'] as String? ?? '',
          instagram: d['instagram'] as String? ?? '',
          postId: 'profile_${widget.uid}',
          ownerUid: widget.uid,
        ),
      ),
    );
  }

  Future<void> _removeFriend() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزالة الصداقة',
            textDirection: TextDirection.rtl),
        content: Text('هل تريد إزالة ${widget.username} من أصدقائك؟',
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
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _removing = true);
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.delete(db
        .collection('friends')
        .doc(widget.myUid)
        .collection('list')
        .doc(widget.uid));
    batch.delete(db
        .collection('friends')
        .doc(widget.uid)
        .collection('list')
        .doc(widget.myUid));
    await batch.commit();
    if (mounted) setState(() => _removing = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: GestureDetector(
        onTap: _viewProfile,
        child: CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFFFFCCE8),
          backgroundImage: widget.photo.isNotEmpty
              ? NetworkImage(widget.photo)
              : null,
          child: widget.photo.isEmpty
              ? const Icon(Icons.person, color: Color(0xFFE91E8C))
              : null,
        ),
      ),
      title: Text(widget.username,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFF3D0030))),
      trailing: _removing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: Color(0xFFE91E8C), strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconBtn(
                  icon: Icons.person_search_rounded,
                  color: const Color(0xFF7C3AED),
                  tooltip: 'مشاهدة الملف',
                  onTap: _viewProfile,
                ),
                const SizedBox(width: 6),
                _IconBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: const Color(0xFFE91E8C),
                  tooltip: 'مراسلة',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: widget.chatId,
                        myUid: widget.myUid,
                        friendUid: widget.uid,
                        friendName: widget.username,
                        friendPhoto: widget.photo,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _IconBtn(
                  icon: Icons.person_remove_rounded,
                  color: Colors.red,
                  tooltip: 'إزالة الصداقة',
                  onTap: _removeFriend,
                ),
              ],
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// تاب الرسائل
// ══════════════════════════════════════════════════════════════════════════════

class _MessagesTab extends StatefulWidget {
  final String myUid;
  const _MessagesTab({required this.myUid});

  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _deleteChat(String chatId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المحادثة',
            textDirection: TextDirection.rtl),
        content: const Text(
            'سيتم حذف هذه المحادثة من قائمتك. هل أنت متأكد؟',
            textDirection: TextDirection.rtl),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: Color(0xFFE91E8C)))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // نضيف uid المستخدم لقائمة "محذوف عندي"
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .update({
        'deletedFor': FieldValue.arrayUnion([widget.myUid]),
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── شريط البحث ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
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
                  color: const Color(0xFFE91E8C).withValues(alpha: 0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              textDirection: TextDirection.rtl,
              style: const TextStyle(color: Color(0xFF3D0030), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ابحث في الرسائل...',
                hintStyle: const TextStyle(
                    color: Color(0xFFBB8899), fontSize: 13),
                prefixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFFE91E8C), size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        })
                    : null,
                suffixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFFE91E8C), size: 22),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),

        // ── قائمة المحادثات ───────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('participants',
                    arrayContains: widget.myUid)
                .orderBy('lastAt', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFE91E8C)));
              }

              final docs = (snap.data?.docs ?? []).where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                // استبعد المحادثات المحذوفة عند هذا المستخدم
                final deletedFor = List<String>.from(
                    d['deletedFor'] as List? ?? []);
                if (deletedFor.contains(widget.myUid)) return false;
                // استبعد المحادثات بدون رسائل
                if ((d['lastMessage'] as String?)?.isEmpty ?? true) {
                  return false;
                }
                return true;
              }).toList();

              // تطبيق البحث
              final filtered = _query.isEmpty
                  ? docs
                  : docs.where((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final names =
                          d['names'] as Map<String, dynamic>? ?? {};
                      final parts = List<String>.from(
                          d['participants'] as List? ?? []);
                      final otherUid = parts.firstWhere(
                          (p) => p != widget.myUid,
                          orElse: () => '');
                      final otherName = (names[otherUid] as String?) ?? '';
                      final lastMsg =
                          (d['lastMessage'] as String?) ?? '';
                      final q = _query.toLowerCase();
                      return otherName.toLowerCase().contains(q) ||
                          lastMsg.toLowerCase().contains(q);
                    }).toList();

              if (filtered.isEmpty) {
                return _EmptyHint(
                  icon: Icons.chat_bubble_outline_rounded,
                  msg: _query.isEmpty
                      ? 'لا رسائل بعد\nراسل أحداً من ملفه الشخصي'
                      : 'لا نتائج لـ "$_query"',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final doc = filtered[i];
                  final d = doc.data() as Map<String, dynamic>;
                  final chatId = doc.id;
                  final parts = List<String>.from(
                      d['participants'] as List? ?? []);
                  final otherUid = parts.firstWhere(
                      (p) => p != widget.myUid,
                      orElse: () => '');
                  final names =
                      d['names'] as Map<String, dynamic>? ?? {};
                  final photos =
                      d['photos'] as Map<String, dynamic>? ?? {};
                  final _rawName = (names[otherUid] as String?) ?? '';
                  final otherName =
                      _rawName.isNotEmpty ? _rawName : 'مستخدم';
                  final otherPhoto =
                      (photos[otherUid] as String?) ?? '';
                  final lastMsg =
                      (d['lastMessage'] as String?) ?? '';
                  final lastFrom =
                      (d['lastFrom'] as String?) ?? '';
                  final lastAt = d['lastAt'] as Timestamp?;
                  final isFromMe = lastFrom == widget.myUid;

                  return _ConversationTile(
                    chatId: chatId,
                    myUid: widget.myUid,
                    otherUid: otherUid,
                    otherName: otherName,
                    otherPhoto: otherPhoto,
                    lastMsg: lastMsg,
                    isFromMe: isFromMe,
                    lastAt: lastAt,
                    searchQuery: _query,
                    onDelete: () => _deleteChat(chatId),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// تاب طلبات الصداقة
// ══════════════════════════════════════════════════════════════════════════════

class _RequestsTab extends StatelessWidget {
  final String myUid;
  const _RequestsTab({required this.myUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('to', isEqualTo: myUid)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE91E8C)));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyHint(
              icon: Icons.person_add_alt_1_rounded,
              msg: 'لا طلبات صداقة جديدة');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (ctx, i) => _RequestTile(myUid: myUid, reqDoc: docs[i]),
        );
      },
    );
  }
}

class _RequestTile extends StatefulWidget {
  final String myUid;
  final QueryDocumentSnapshot reqDoc;
  const _RequestTile({required this.myUid, required this.reqDoc});

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  bool _loading = false;

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      final db = FirebaseFirestore.instance;
      final d = widget.reqDoc.data() as Map<String, dynamic>;
      final fromUid = d['from'] as String? ?? '';
      final fromUsername = (d['fromUsername'] as String?)?.isNotEmpty == true
          ? d['fromUsername'] as String
          : (d['fromName'] as String? ?? 'مستخدم');
      final fromPhoto = d['fromPhoto'] as String? ?? '';

      final myDoc = await db.collection('users').doc(widget.myUid).get();
      final myUsername = (myDoc.data()?['username'] as String?)?.isNotEmpty == true
          ? myDoc.data()!['username'] as String
          : (myDoc.data()?['name'] as String? ?? 'مستخدم');
      final myPhoto =
          ((myDoc.data()?['photoUrls'] as List?)?.firstOrNull as String?) ?? '';

      final chatId = _makeChatId(widget.myUid, fromUid);
      final batch = db.batch();

      batch.set(
        db.collection('friends').doc(widget.myUid).collection('list').doc(fromUid),
        {
          'uid': fromUid,
          'username': fromUsername,
          'name': fromUsername,
          'photoUrl': fromPhoto,
          'chatId': chatId,
          'addedAt': FieldValue.serverTimestamp(),
        },
      );

      batch.set(
        db.collection('friends').doc(fromUid).collection('list').doc(widget.myUid),
        {
          'uid': widget.myUid,
          'username': myUsername,
          'name': myUsername,
          'photoUrl': myPhoto,
          'chatId': chatId,
          'addedAt': FieldValue.serverTimestamp(),
        },
      );

      const greetText = 'أصبحنا أصدقاء! 👋';

      batch.set(
        db.collection('chats').doc(chatId),
        {
          'participants': [widget.myUid, fromUid],
          'lastMessage': greetText,
          'lastFrom': widget.myUid,
          'lastAt': FieldValue.serverTimestamp(),
          'names': {
            widget.myUid: myUsername,
            fromUid: fromUsername,
          },
          'photos': {
            widget.myUid: myPhoto,
            fromUid: fromPhoto,
          },
        },
        SetOptions(merge: true),
      );

      // رسالة حقيقية تظهر في المحادثة
      batch.set(
        db.collection('chats').doc(chatId).collection('messages').doc(),
        {
          'from': widget.myUid,
          'text': greetText,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        },
      );

      // إشعار للصديق في الصندوق
      batch.set(
        db.collection('inbox').doc(fromUid).collection('messages').doc(),
        {
          'type': 'message',
          'from': widget.myUid,
          'fromName': myUsername,
          'fromPhoto': myPhoto,
          'text': greetText,
          'chatId': chatId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      batch.delete(widget.reqDoc.reference);
      await batch.commit();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _reject() async {
    setState(() => _loading = true);
    try {
      await widget.reqDoc.reference.delete();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.reqDoc.data() as Map<String, dynamic>;
    final fromUsername = (d['fromUsername'] as String?)?.isNotEmpty == true
        ? d['fromUsername'] as String
        : (d['fromName'] as String? ?? 'مستخدم');
    final fromPhoto = d['fromPhoto'] as String? ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFFFFCCE8),
        backgroundImage: fromPhoto.isNotEmpty ? NetworkImage(fromPhoto) : null,
        child: fromPhoto.isEmpty
            ? const Icon(Icons.person, color: Color(0xFFE91E8C))
            : null,
      ),
      title: Text(fromUsername,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFF3D0030))),
      subtitle: const Text('يريد إضافتك كصديق',
          style: TextStyle(color: Color(0xFFBB8899), fontSize: 12)),
      trailing: _loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: Color(0xFFE91E8C), strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconBtn(
                  icon: Icons.check_rounded,
                  color: const Color(0xFF22C55E),
                  tooltip: 'قبول',
                  onTap: _approve,
                ),
                const SizedBox(width: 6),
                _IconBtn(
                  icon: Icons.close_rounded,
                  color: Colors.red,
                  tooltip: 'رفض',
                  onTap: _reject,
                ),
              ],
            ),
    );
  }
}

// ─── Conversation Tile ────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final String chatId;
  final String myUid;
  final String otherUid;
  final String otherName;
  final String otherPhoto;
  final String lastMsg;
  final bool isFromMe;
  final Timestamp? lastAt;
  final String searchQuery;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.chatId,
    required this.myUid,
    required this.otherUid,
    required this.otherName,
    required this.otherPhoto,
    required this.lastMsg,
    required this.isFromMe,
    required this.lastAt,
    required this.searchQuery,
    required this.onDelete,
  });

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} د';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} س';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} ي';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(chatId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_rounded,
            color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // نتعامل مع الحذف يدوياً
      },
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              myUid: myUid,
              friendUid: otherUid,
              friendName: otherName,
              friendPhoto: otherPhoto,
            ),
          ),
        ),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFFFFCCE8),
          backgroundImage:
              otherPhoto.isNotEmpty ? NetworkImage(otherPhoto) : null,
          child: otherPhoto.isEmpty
              ? const Icon(Icons.person, color: Color(0xFFE91E8C))
              : null,
        ),
        title: _HighlightText(
          text: otherName,
          query: searchQuery,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D0030),
              fontSize: 15),
        ),
        subtitle: Row(
          children: [
            if (isFromMe)
              const Text('أنت: ',
                  style: TextStyle(
                      color: Color(0xFFE91E8C),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            Expanded(
              child: _HighlightText(
                text: lastMsg,
                query: searchQuery,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFFBB8899), fontSize: 12),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_formatTime(lastAt),
                style: const TextStyle(
                    color: Color(0xFFBB8899), fontSize: 11)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Highlight Search Text ────────────────────────────────────────────────────

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  const _HighlightText({
    required this.text,
    required this.query,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text,
          style: style, maxLines: maxLines, overflow: overflow);
    }
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final idx = lower.indexOf(q);
    if (idx < 0) {
      return Text(text,
          style: style, maxLines: maxLines, overflow: overflow);
    }
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: text.substring(0, idx), style: style),
        TextSpan(
          text: text.substring(idx, idx + q.length),
          style: style.copyWith(
            backgroundColor:
                const Color(0xFFE91E8C).withValues(alpha: 0.2),
            color: const Color(0xFFE91E8C),
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(text: text.substring(idx + q.length), style: style),
      ]),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

// ─── Shared Helpers ───────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn(
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
                color: color.withValues(alpha: 0.4), width: 1.2),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String msg;
  const _EmptyHint({required this.icon, required this.msg});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 70,
              color: Colors.pink.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFFBB8899), fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }
}

String _makeChatId(String a, String b) {
  final s = [a, b]..sort();
  return '${s[0]}_${s[1]}';
}
