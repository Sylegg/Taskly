import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/api.dart';
import '../domain/models.dart';

abstract final class CommunityTheme {
  static const ink = Color(0xFF0F172A);
  static const slate = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const subtle = Color(0xFF94A3B8);
  static const emerald = Color(0xFF0F9D7A);
  static const emeraldDark = Color(0xFF087A60);
  static const emeraldSoft = Color(0xFFE8F7F2);
  static const cardBorder = Color(0xFFEDF2F7);
  static const background = Color(0xFFF8FAFC);
  static const coral = Color(0xFFFF2D55);
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

Widget _cover(CommunityArticle a) => AspectRatio(
  aspectRatio: 16 / 9,
  child: ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          a.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: CommunityTheme.emeraldSoft,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.image_outlined,
                    color: CommunityTheme.emerald,
                    size: 40,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'TaskLy Community',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CommunityTheme.emerald,
                    ),
                  ),
                ],
              ),
            ),
          ),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : Container(
                  color: CommunityTheme.emeraldSoft,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: CommunityTheme.emerald,
                    ),
                  ),
                ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ],
    ),
  ),
);

class CommunityFeed extends StatelessWidget {
  const CommunityFeed({
    super.key,
    required this.articles,
    required this.onArticle,
    this.session,
  });

  final List<CommunityArticle> articles;
  final ValueChanged<String> onArticle;
  final Session? session;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (session == null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF087A60), CommunityTheme.emerald],
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_stories_outlined, color: Colors.white, size: 32),
              SizedBox(height: 16),
              Text(
                'Góc sống thảnh thơi',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Chuyện nhà, kinh nghiệm và những cập nhật từ TaskLy.',
                style: TextStyle(color: Colors.white, height: 1.5),
              ),
            ],
          ),
        ),
      if (articles.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  color: CommunityTheme.emerald,
                  size: 44,
                ),
                SizedBox(height: 12),
                Text(
                  'Chưa có bài viết',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  'Bài mới từ TaskLy sẽ xuất hiện tại đây.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        )
      else
        for (final article in articles)
          if (session != null)
            CommunityPost(
              article: article,
              session: session!,
              onArticle: onArticle,
            )
          else
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CommunityTheme.cardBorder, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x060F172A),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('community-article-${article.id}'),
                  onTap: () => onArticle(article.id),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cover(article),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: CommunityTheme.emeraldSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'TASKLY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: CommunityTheme.emerald,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _date(article.createdAt.toLocal()),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: CommunityTheme.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          article.title,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                            color: CommunityTheme.ink,
                          ),
                        ),
                        if (article.summary.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            article.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: CommunityTheme.slate,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Text(
                              'Đọc bài viết',
                              style: TextStyle(
                                color: CommunityTheme.emerald,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                              color: CommunityTheme.emerald,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    ],
  );
}

class CommunityPost extends StatefulWidget {
  const CommunityPost({
    super.key,
    required this.article,
    required this.session,
    required this.onArticle,
  });

  final CommunityArticle article;
  final Session session;
  final ValueChanged<String> onArticle;

  @override
  State<CommunityPost> createState() => _CommunityPostState();
}

class _CommunityPostState extends State<CommunityPost> {
  Map<String, dynamic> engagement = {};
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.session.request(
        '/community/articles/${widget.article.id}/engagement',
      );
      if (mounted) {
        setState(() => engagement = Map<String, dynamic>.from(result));
      }
    } catch (_) {
      /* Counts stay unavailable until a successful request. */
    }
  }

  void error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> react(String kind) async {
    setState(() => busy = true);
    try {
      final result = await widget.session.request(
        '/community/articles/${widget.article.id}/reaction',
        method: 'PUT',
        body: {
          'kind': kind,
          'selected': engagement[kind == 'LIKE' ? 'liked' : 'reposted'] != true,
        },
      );
      if (mounted) {
        setState(() => engagement = Map<String, dynamic>.from(result));
      }
    } catch (e) {
      error(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> comments() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          CommunityComments(session: widget.session, article: widget.article),
    );
    await load();
  }

  String age() {
    final elapsed = DateTime.now().difference(widget.article.createdAt);
    if (elapsed.inMinutes < 1) return 'Vừa xong';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} phút';
    if (elapsed.inDays < 1) return '${elapsed.inHours} giờ';
    if (elapsed.inDays < 7) return '${elapsed.inDays} ngày';
    return _date(widget.article.createdAt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.article;
    final preview = a.summary.isNotEmpty ? a.summary : a.content;
    final initial = a.authorName.trim().isEmpty ? 'T' : a.authorName.trim()[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CommunityTheme.cardBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Author & Meta
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), CommunityTheme.emeraldDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: CommunityTheme.emerald.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              a.authorName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: CommunityTheme.ink,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: CommunityTheme.emerald,
                          ),
                          if (a.groupName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: CommunityTheme.emeraldSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                a.groupName,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: CommunityTheme.emeraldDark,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            age(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: CommunityTheme.muted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('•', style: TextStyle(color: CommunityTheme.subtle, fontSize: 10)),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.public_rounded,
                            size: 12,
                            color: CommunityTheme.subtle,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Tùy chọn bài đăng',
                  icon: const Icon(Icons.more_horiz_rounded, color: CommunityTheme.muted),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (val) {
                    if (val == 'read') widget.onArticle(a.id);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'read',
                      child: Text('Xem bài viết'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content clickable area
          InkWell(
            key: ValueKey('community-article-${a.id}'),
            onTap: () => widget.onArticle(a.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      color: CommunityTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: CommunityTheme.slate,
                    ),
                  ),
                  if (a.hashtag.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: CommunityTheme.emeraldSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '#${a.hashtag}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: CommunityTheme.emeraldDark,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // Image cover
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: InkWell(
              onTap: () => widget.onArticle(a.id),
              child: _cover(a),
            ),
          ),

          // Engagement bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _action(
                  engagement['liked'] == true
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  'Thích',
                  engagement['likes'],
                  () => react('LIKE'),
                  selected: engagement['liked'] == true,
                ),
                _action(
                  Icons.chat_bubble_outline,
                  'Bình luận',
                  engagement['comments'],
                  comments,
                ),
                _action(
                  Icons.repeat,
                  'Đăng lại',
                  engagement['reposts'],
                  () => react('REPOST'),
                  selected: engagement['reposted'] == true,
                ),
                IconButton(
                  tooltip: 'Chia sẻ bài viết',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            '${a.title}\n${widget.session.api.publicAssetUrl('/api/v1/public/articles/${a.id}')}',
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép liên kết bài viết.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.share_outlined,
                    color: Color(0xFF465160),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(
    IconData icon,
    String label,
    dynamic count,
    VoidCallback callback, {
    bool selected = false,
  }) => TextButton(
    onPressed: busy ? null : callback,
    style: TextButton.styleFrom(
      foregroundColor: selected
          ? const Color(0xFFF5882E)
          : const Color(0xFF465160),
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, semanticLabel: label),
        if (count != null && count > 0) ...[
          const SizedBox(width: 4),
          Text('$count'),
        ],
      ],
    ),
  );
}

class CommunityComments extends StatefulWidget {
  const CommunityComments({
    super.key,
    required this.session,
    required this.article,
  });

  final Session session;
  final CommunityArticle article;

  @override
  State<CommunityComments> createState() => _CommunityCommentsState();
}

class _CommunityCommentsState extends State<CommunityComments> {
  final input = TextEditingController();
  List<dynamic> items = [];
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final result = await widget.session.request(
        '/community/articles/${widget.article.id}/comments',
      );
      if (mounted) setState(() => items = result as List);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> send() async {
    if (input.text.trim().isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.request(
        '/community/articles/${widget.article.id}/comments',
        method: 'POST',
        body: {'content': input.text.trim()},
      );
      input.clear();
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  const Text(
                    'Bình luận',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: CommunityTheme.ink,
                    ),
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: CommunityTheme.emeraldSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${items.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: CommunityTheme.emeraldDark,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: CommunityTheme.muted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: CommunityTheme.cardBorder),
            if (error != null)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error!,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 40,
                            color: CommunityTheme.subtle.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Chưa có bình luận nào.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: CommunityTheme.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Hãy là người đầu tiên chia sẻ cảm nghĩ!',
                            style: TextStyle(fontSize: 12.5, color: CommunityTheme.subtle),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, idx) {
                        final item = items[idx];
                        final author = item['authorName']?.toString() ?? 'Thành viên';
                        final letter = author.trim().isEmpty ? 'U' : author.trim()[0].toUpperCase();
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: CommunityTheme.emeraldSoft,
                              child: Text(
                                letter,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: CommunityTheme.emeraldDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: CommunityTheme.cardBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      author,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                        color: CommunityTheme.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['content']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        height: 1.4,
                                        color: CommunityTheme.slate,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const Divider(height: 1, color: CommunityTheme.cardBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: input,
                        maxLength: 2000,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Viết bình luận…',
                          hintStyle: TextStyle(fontSize: 14, color: CommunityTheme.muted),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          counterText: '',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: CommunityTheme.emerald,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      tooltip: 'Gửi bình luận',
                      onPressed: busy ? null : send,
                      icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CommunityArticleView extends StatelessWidget {
  const CommunityArticleView({super.key, required this.article});

  final CommunityArticle? article;

  @override
  Widget build(BuildContext context) {
    final a = article;
    if (a == null) {
      return Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: CommunityTheme.cardBorder),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, color: CommunityTheme.muted, size: 36),
              SizedBox(height: 12),
              Text(
                'Bài viết không còn hiển thị. Vui lòng quay lại Cộng đồng.',
                textAlign: TextAlign.center,
                style: TextStyle(color: CommunityTheme.slate, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CommunityTheme.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(18), child: _cover(a)),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: CommunityTheme.emeraldSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  a.groupName.isNotEmpty ? a.groupName.toUpperCase() : 'CỘNG ĐỒNG TASKLY',
                  style: const TextStyle(
                    fontSize: 11,
                    color: CommunityTheme.emeraldDark,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _date(a.createdAt.toLocal()),
                style: const TextStyle(
                  fontSize: 12,
                  color: CommunityTheme.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SelectableText(
            a.title,
            style: const TextStyle(
              fontSize: 23,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: CommunityTheme.ink,
            ),
          ),
          const SizedBox(height: 12),
          // Author card
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: CommunityTheme.emeraldSoft,
                child: Text(
                  a.authorName.isNotEmpty ? a.authorName[0].toUpperCase() : 'T',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: CommunityTheme.emeraldDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                a.authorName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: CommunityTheme.slate,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.verified_rounded, size: 14, color: CommunityTheme.emerald),
            ],
          ),
          const SizedBox(height: 18),
          if (a.summary.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: const Border(
                  left: BorderSide(color: CommunityTheme.emerald, width: 3.5),
                ),
              ),
              child: SelectableText(
                a.summary,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  height: 1.55,
                  color: CommunityTheme.slate,
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          const Divider(color: CommunityTheme.cardBorder),
          const SizedBox(height: 14),
          SelectableText(
            a.content,
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.75,
              color: CommunityTheme.ink,
            ),
          ),
          const SizedBox(height: 24),
          if (a.hashtag.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: CommunityTheme.emeraldSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '#${a.hashtag}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: CommunityTheme.emeraldDark,
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
