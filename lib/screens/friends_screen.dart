import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'post_detail_screen.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF0F7),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFF0F7),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF3D0030)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('الأصدقاء',
              style: TextStyle(
                  color: Color(0xFF3D0030), fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Color(0xFFE91E8C),
            unselectedLabelColor: Color(0xFFBB8899),
            indicatorColor: Color(0xFFE91E8C),
            tabs: [
              Tab(text: 'أصدقائي'),
              Tab(text: 'الطلبات'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_FriendsTab(), _RequestsTab()],
        ),
      ),
    );
  }
}

// ─── My Friends ───────────────────────────────────────────────────────────────

class _FriendsTab extends StatelessWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const _EmptyHint(msg: 'سجّل دخولاً أولاً');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friends')
          .doc(uid)
          .collection('list')
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE91E8C)));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyHint(
              msg: 'لا أصدقاء بعد\nأضف أصدقاء من صفحة ملفاتهم الشخصية');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final friendUid = docs[i].id;
            final name = d['name'] as String? ?? 'مستخدم';
            final photo = d['photoUrl'] as String? ?? '';
            final chatId =
                d['chatId'] as String? ?? _makeChatId(uid, friendUid);
            return _FriendTile(
                uid: friendUid, name: name, photo: photo, chatId: chatId);
          },
        );
      },
    );
  }
}

class _FriendTile extends StatefulWidget {
  final String uid;
  final String name;
  final String photo;
  final String chatId;
  const _FriendTile(
      {required this.uid,
      required this.name,
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
    final photos =
        List<String>.from(d['photoUrls'] as List? ?? []);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          photos: photos,
          name: d['name'] as String? ?? widget.name,
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
        content: Text(
            'هل تريد إزالة ${widget.name} من أصدقائك؟',
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
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.delete(db
        .collection('friends')
        .doc(myUid)
        .collection('list')
        .doc(widget.uid));
    batch.delete(db
        .collection('friends')
        .doc(widget.uid)
        .collection('list')
        .doc(myUid));
    await batch.commit();
    if (mounted) setState(() => _removing = false);
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: GestureDetector(
        onTap: _viewProfile,
        child: CircleAvatar(
          radius: 26,
          backgroundColor: const Color(0xFFFFCCE8),
          backgroundImage:
              widget.photo.isNotEmpty ? NetworkImage(widget.photo) : null,
          child: widget.photo.isEmpty
              ? const Icon(Icons.person, color: Color(0xFFE91E8C))
              : null,
        ),
      ),
      title: Text(widget.name,
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
                // مشاهدة الملف
                _IconBtn(
                  icon: Icons.person_search_rounded,
                  color: const Color(0xFF7C3AED),
                  tooltip: 'مشاهدة الملف',
                  onTap: _viewProfile,
                ),
                const SizedBox(width: 6),
                // مراسلة
                _IconBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: const Color(0xFFE91E8C),
                  tooltip: 'مراسلة',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: widget.chatId,
                        myUid: myUid,
                        friendUid: widget.uid,
                        friendName: widget.name,
                        friendPhoto: widget.photo,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // إزالة الصداقة
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
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

// ─── Incoming Requests ────────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const _EmptyHint(msg: 'سجّل دخولاً أولاً');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('to', isEqualTo: uid)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE91E8C)));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyHint(msg: 'لا طلبات صداقة جديدة');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _RequestTile(
              docId: docs[i].id,
              fromUid: d['from'] as String? ?? '',
              fromName: d['fromName'] as String? ?? 'مستخدم',
              fromPhoto: d['fromPhoto'] as String? ?? '',
              toUid: uid,
            );
          },
        );
      },
    );
  }
}

class _RequestTile extends StatefulWidget {
  final String docId;
  final String fromUid;
  final String fromName;
  final String fromPhoto;
  final String toUid;
  const _RequestTile({
    required this.docId,
    required this.fromUid,
    required this.fromName,
    required this.fromPhoto,
    required this.toUid,
  });

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  bool _loading = false;
  final _db = FirebaseFirestore.instance;

  Future<void> _accept() async {
    setState(() => _loading = true);
    try {
      final chatId = _makeChatId(widget.fromUid, widget.toUid);
      final myDoc = await _db.collection('users').doc(widget.toUid).get();
      final myName = (myDoc.data()?['name'] as String?) ?? 'مستخدم';
      final myPhoto =
          ((myDoc.data()?['photoUrls'] as List?)?.firstOrNull as String?) ?? '';

      final batch = _db.batch();
      batch.delete(_db.collection('friend_requests').doc(widget.docId));
      batch.set(
        _db.collection('friends').doc(widget.toUid).collection('list').doc(widget.fromUid),
        {'uid': widget.fromUid, 'name': widget.fromName, 'photoUrl': widget.fromPhoto, 'chatId': chatId, 'addedAt': FieldValue.serverTimestamp()},
      );
      batch.set(
        _db.collection('friends').doc(widget.fromUid).collection('list').doc(widget.toUid),
        {'uid': widget.toUid, 'name': myName, 'photoUrl': myPhoto, 'chatId': chatId, 'addedAt': FieldValue.serverTimestamp()},
      );
      batch.set(_db.collection('chats').doc(chatId),
          {'participants': [widget.fromUid, widget.toUid], 'lastMessage': '', 'lastAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
      batch.set(
        _db.collection('inbox').doc(widget.fromUid).collection('messages').doc(),
        {'type': 'friend_accepted', 'from': widget.toUid, 'fromName': myName, 'text': '$myName قبل طلب صداقتك', 'read': false, 'createdAt': FieldValue.serverTimestamp()},
      );
      await batch.commit();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _loading = true);
    try {
      await _db.collection('friend_requests').doc(widget.docId).delete();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFFFFCCE8),
        backgroundImage: widget.fromPhoto.isNotEmpty
            ? NetworkImage(widget.fromPhoto)
            : null,
        child: widget.fromPhoto.isEmpty
            ? const Icon(Icons.person, color: Color(0xFFE91E8C))
            : null,
      ),
      title: Text(widget.fromName,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D0030))),
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
                GestureDetector(
                  onTap: _accept,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: Color(0xFFE91E8C),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _decline,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.black54, size: 18),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _makeChatId(String a, String b) {
  final s = [a, b]..sort();
  return '${s[0]}_${s[1]}';
}

class _EmptyHint extends StatelessWidget {
  final String msg;
  const _EmptyHint({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded,
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
