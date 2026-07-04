import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'post_detail_screen.dart';

class SmartSearchScreen extends StatefulWidget {
  const SmartSearchScreen({super.key});

  @override
  State<SmartSearchScreen> createState() => _SmartSearchScreenState();
}

class _SmartSearchScreenState extends State<SmartSearchScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _FilterType _filterType = _FilterType.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<UserModel> _applyFilter(List<UserModel> all) {
    final q = _query.trim().toLowerCase();
    List<UserModel> list = all;

    if (q.isNotEmpty) {
      list = list.where((u) {
        switch (_filterType) {
          case _FilterType.name:
            return u.name.toLowerCase().contains(q);
          case _FilterType.username:
            return u.username.toLowerCase().contains(q);
          case _FilterType.age:
            return u.age.toString() == q;
          case _FilterType.bio:
            return u.bio.toLowerCase().contains(q);
          case _FilterType.uid:
            return u.uid.toLowerCase().contains(q);
          case _FilterType.all:
            return u.name.toLowerCase().contains(q) ||
                u.username.toLowerCase().contains(q) ||
                u.bio.toLowerCase().contains(q) ||
                u.age.toString() == q ||
                u.uid.toLowerCase().contains(q);
        }
      }).toList();
    }

    // ترتيب: المنشورون أولاً ثم غير المنشورين، وبالاسم
    list.sort((a, b) {
      if (a.published && !b.published) return -1;
      if (!a.published && b.published) return 1;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A0012),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.manage_search_rounded,
                color: Color(0xFFE91E8C), size: 22),
            SizedBox(width: 8),
            Text('البحث الذكي',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── شريط البحث ───────────────────────────────────────────────
          Container(
            color: const Color(0xFF1A0012),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Column(
              children: [
                // حقل البحث
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFE91E8C).withValues(alpha: 0.6),
                        width: 1.2),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'ابحث...',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13),
                      prefixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Color(0xFFE91E8C), size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      suffixIcon: const Icon(Icons.search_rounded,
                          color: Color(0xFFE91E8C), size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(height: 10),
                // فلاتر
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _FilterType.values
                        .map((f) => _FilterChip(
                              label: f.label,
                              selected: _filterType == f,
                              onTap: () => setState(() => _filterType = f),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── النتائج ──────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFE91E8C)));
                }
                if (snap.hasError) {
                  return Center(
                      child: Text('خطأ: ${snap.error}',
                          style:
                              const TextStyle(color: Color(0xFFBB8899))));
                }

                final all = (snap.data?.docs ?? [])
                    .map((d) => UserModel.fromMap(d.id,
                        d.data() as Map<String, dynamic>))
                    .toList();

                final results = _applyFilter(all);

                // رأس عداد النتائج
                final header = Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        '${results.length} مستخدم',
                        style: const TextStyle(
                            color: Color(0xFFE91E8C),
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        'الكل: ${all.length}',
                        style: const TextStyle(
                            color: Color(0xFFBB8899), fontSize: 12),
                      ),
                    ],
                  ),
                );

                if (results.isEmpty) {
                  return Column(
                    children: [
                      header,
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  size: 60,
                                  color: Colors.pink.withValues(alpha: 0.25)),
                              const SizedBox(height: 12),
                              Text(
                                _query.isEmpty
                                    ? 'لا يوجد مستخدمون بعد'
                                    : 'لا نتائج لـ "$_query"',
                                style: const TextStyle(
                                    color: Color(0xFFBB8899), fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    header,
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: results.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (ctx, i) =>
                            _UserTile(user: results[i]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Types ─────────────────────────────────────────────────────────────

enum _FilterType {
  all,
  name,
  username,
  age,
  bio,
  uid;

  String get label {
    switch (this) {
      case _FilterType.all:      return 'الكل';
      case _FilterType.name:     return 'الاسم';
      case _FilterType.username: return 'المعرّف #';
      case _FilterType.age:      return 'العمر';
      case _FilterType.bio:      return 'البيو';
      case _FilterType.uid:      return 'UID';
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE91E8C)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFFE91E8C)
                : Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─── User Tile ────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final UserModel user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final photo =
        user.photoUrls.isNotEmpty ? user.photoUrls.first : '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailScreen.fromProfile(user),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: user.published
                ? const Color(0xFFFFCCE8)
                : Colors.grey.withValues(alpha: 0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE91E8C).withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFFFCCE8),
                child: photo.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: photo,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const Icon(
                              Icons.person,
                              color: Color(0xFFE91E8C)),
                        ),
                      )
                    : const Icon(Icons.person,
                        color: Color(0xFFE91E8C), size: 26),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: user.published
                        ? const Color(0xFF22C55E)
                        : Colors.grey[400],
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  user.name.isEmpty ? '(بدون اسم)' : user.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: user.name.isEmpty
                        ? Colors.grey
                        : const Color(0xFF3D0030),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E8C),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${user.age > 0 ? user.age : '?'} سنة',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user.username.isNotEmpty)
                Text(
                  '# ${user.username}',
                  style: const TextStyle(
                      color: Color(0xFFE91E8C),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              if (user.bio.isNotEmpty)
                Text(
                  user.bio,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFFBB8899)),
                ),
              Text(
                user.uid,
                style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                    fontFamily: 'monospace'),
              ),
            ],
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Colors.grey[400],
          ),
        ),
      ),
    );
  }
}
