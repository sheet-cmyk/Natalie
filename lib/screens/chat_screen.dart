import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _db
        .collection('users')
        .doc(widget.myUid)
        .get()
        .then((d) => _myName = (d.data()?['name'] as String?) ?? 'مستخدم');
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
      },
    );

    batch.set(
      _db.collection('chats').doc(widget.chatId),
      {
        'participants': [widget.myUid, widget.friendUid],
        'lastMessage': text,
        'lastFrom': widget.myUid,
        'lastAt': FieldValue.serverTimestamp(),
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
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    return _Bubble(
                      text: d['text'] as String? ?? '',
                      isMe: d['from'] == widget.myUid,
                    );
                  },
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

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final String text;
  final bool isMe;
  const _Bubble({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
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
        child: Text(
          text,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: isMe ? Colors.white : const Color(0xFF3D0030),
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
