import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_screen.dart' show isAdminUser;

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String myUid;
  final String friendUid;
  final String friendName;
  final String friendPhoto;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.myUid,
    required this.friendUid,
    required this.friendName,
    required this.friendPhoto,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _db = FirebaseFirestore.instance;
  String _myName = '';
  String _myPhoto = '';
  bool _sending = false;
  late Future<void> _identityFuture;

  @override
  void initState() {
    super.initState();
    _identityFuture = _loadMyIdentity();
    _markAsRead();
  }

  Future<void> _loadMyIdentity() async {
    final snap = await _db.collection('users').doc(widget.myUid).get();
    if (snap.exists) {
      final data = snap.data()!;
      final name     = (data['name']     as String?)?.trim() ?? '';
      final username = (data['username'] as String?)?.trim() ?? '';
      _myName  = name.isNotEmpty ? name : (username.isNotEmpty ? username : 'مستخدم');
      final photos = List<String>.from(data['photoUrls'] ?? []);
      _myPhoto = photos.isNotEmpty ? photos.first : '';
    } else if (isAdminUser()) {
      final adminSnap = await _db.collection('config').doc('admin_profile').get();
      final data = adminSnap.data() ?? {};
      final name = (data['name'] as String?)?.trim() ?? '';
      _myName  = name.isNotEmpty ? name : 'Admin';
      _myPhoto = data['photoUrl'] as String? ?? '';
    } else {
      _myName  = 'مستخدم';
      _myPhoto = '';
    }
  }

  Future<void> _markAsRead() async {
    try {
      final unread = await _db
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('from', isEqualTo: widget.friendUid)
          .where('read', isEqualTo: false)
          .get();
      if (unread.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _textCtrl.clear();
    await _identityFuture;

    final batch = _db.batch();

    batch.set(
      _db
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(),
      {
        'from': widget.myUid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      },
    );

    batch.set(
      _db.collection('chats').doc(widget.chatId),
      {
        'participants': [widget.myUid, widget.friendUid],
        'lastMessage': text,
        'lastFrom': widget.myUid,
        'lastAt': FieldValue.serverTimestamp(),
        'names': {
          widget.myUid: _myName,
          widget.friendUid: widget.friendName,
        },
        'photos': {
          widget.myUid: _myPhoto,
          widget.friendUid: widget.friendPhoto,
        },
      },
      SetOptions(merge: true),
    );

    batch.set(
      _db
          .collection('inbox')
          .doc(widget.friendUid)
          .collection('messages')
          .doc(),
      {
        'type': 'message',
        'from': widget.myUid,
        'fromName': _myName,
        'text': text,
        'chatId': widget.chatId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
    if (mounted) setState(() => _sending = false);

    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF0F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF3D0030)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFFFCCE8),
              backgroundImage: widget.friendPhoto.isNotEmpty
                  ? NetworkImage(widget.friendPhoto)
                  : null,
              child: widget.friendPhoto.isEmpty
                  ? const Icon(Icons.person,
                      color: Color(0xFFE91E8C), size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              widget.friendName,
              style: const TextStyle(
                  color: Color(0xFF3D0030),
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Messages ──────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFE91E8C)));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('ابدأ المحادثة!',
                        style: TextStyle(color: Color(0xFFBB8899))),
                  );
                }

                // Mark incoming unread messages as read
                final hasUnread = docs.any((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return d['from'] == widget.friendUid &&
                      d['read'] == false;
                });
                if (hasUnread) {
                  WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _markAsRead());
                }

                _scrollToBottom();

                // Build items with date separators
                final List<Widget> items = [];
                DateTime? lastDay;

                for (final doc in docs) {
                  final d = doc.data() as Map<String, dynamic>;
                  final ts = d['createdAt'] as Timestamp?;
                  final dt = ts?.toDate().toLocal();

                  if (dt != null) {
                    final day = DateTime(dt.year, dt.month, dt.day);
                    if (lastDay == null || lastDay != day) {
                      lastDay = day;
                      items.add(_DateChip(date: day));
                    }
                  }

                  items.add(_Bubble(
                    text: d['text'] as String? ?? '',
                    isMe: d['from'] == widget.myUid,
                    createdAt: ts,
                    read: d['read'] as bool? ?? true,
                  ));
                }

                return ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  children: items,
                );
              },
            ),
          ),

          // ── Input ─────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                  top: BorderSide(color: Color(0xFFFFCCE8), width: 1)),
            ),
            padding: EdgeInsets.fromLTRB(
                12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    textDirection: TextDirection.rtl,
                    maxLines: null,
                    style: const TextStyle(color: Color(0xFF3D0030)),
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة...',
                      hintStyle:
                          const TextStyle(color: Color(0xFFBB8899)),
                      filled: true,
                      fillColor: const Color(0xFFFFF0F7),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                        color: Color(0xFFE91E8C),
                        shape: BoxShape.circle),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Date Separator ───────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final DateTime date;
  const _DateChip({required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    if (date.year == now.year) {
      return '${date.day} ${months[date.month - 1]}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE0F2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _label(),
          style: const TextStyle(color: Color(0xFFBB8899), fontSize: 12),
        ),
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final Timestamp? createdAt;
  final bool read;

  const _Bubble({
    required this.text,
    required this.isMe,
    this.createdAt,
    this.read = true,
  });

  String _timeStr() {
    if (createdAt == null) return '';
    final dt = createdAt!.toDate().toLocal();
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final isPm = h >= 12;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m ${isPm ? "م" : "ص"}';
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _timeStr();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFE91E8C) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMe
                ? const Radius.circular(18)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF3D0030),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (timeStr.isNotEmpty)
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white60
                          : const Color(0xFFBB8899),
                    ),
                  ),
                if (isMe) ...[
                  const SizedBox(width: 3),
                  Icon(
                    read
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 14,
                    color: read
                        ? const Color(0xFF82CFFF)
                        : Colors.white60,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
