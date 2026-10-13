import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../auth/api.dart';
import 'partner_ui_kit.dart';

class RecruitmentAcademy extends StatefulWidget {
  const RecruitmentAcademy({super.key, required this.session});
  final Session session;

  @override
  State<RecruitmentAcademy> createState() => _RecruitmentAcademyState();
}

class _RecruitmentAcademyState extends State<RecruitmentAcademy> {
  List<dynamic> lessons = [];
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final result = await widget.session.request('/partner/training/courses');
      if (mounted) {
        setState(() {
          lessons = result is List ? result : [];
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  int get completedCount =>
      lessons.where((p) => p['status'] == 'COMPLETED').length;

  @override
  Widget build(BuildContext context) {
    final total = lessons.length;
    final completed = completedCount;
    final progressRatio = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Partner Academy',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            tooltip: 'Tải lại tiến độ',
            onPressed: busy ? null : load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (busy && lessons.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),

            if (busy && lessons.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    color: PartnerColors.primary,
                    backgroundColor: Color(0xFFDBEAFE),
                  ),
                ),
              ),

            // Error notice
            if (error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFDC2626), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        onPressed: busy ? null : load,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFDC2626)),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Thử tải lại'),
                      ),
                    ),
                  ],
                ),
              ),

            // Hero Header
            _buildAcademyHeader(completed, total, progressRatio),

            const SizedBox(height: 20),

            // Title section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Danh sách bài học nghiệp vụ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (total > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$completed/$total đã học',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PartnerColors.primary,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Empty state
            if (lessons.isEmpty && !busy)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(
                        Icons.video_library_outlined,
                        size: 28,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Admin chưa đăng video đào tạo. Bài học sẽ xuất hiện tại đây khi được mở.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

            // Lesson cards
            ...List.generate(lessons.length, (i) {
              final p = lessons[i];
              return _buildLessonCard(p, i + 1);
            }),

            const SizedBox(height: 20),

            Center(
              child: TextButton.icon(
                onPressed: busy ? null : load,
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Tải lại tiến độ'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcademyHeader(int completed, int total, double ratio) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: PartnerColors.luxuryBlueGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x201E40AF),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Học viện Partner Academy',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Chương trình đào tạo chuẩn 5 sao',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDBEAFE),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Xem toàn bộ video nghiệp vụ và trả lời đúng câu hỏi kiểm tra ở mỗi bài để hoàn tất điều kiện nhận việc.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tiến độ hoàn thành',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(ratio * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF34D399),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(dynamic p, int lessonNumber) {
    final lesson = p['lesson'];
    final status = p['status']?.toString() ?? 'LOCKED';
    final isLocked = status == 'LOCKED';
    final isDone = status == 'COMPLETED';
    final isInProgress = status == 'IN_PROGRESS';
    final durationSeconds = lesson['durationSeconds'] ?? 0;
    final watchedSeconds = p['watchedSeconds'] ?? 0;
    final isDemo = lesson['demo'] == true;

    Color badgeColor = const Color(0xFF64748B);
    Color badgeBg = const Color(0xFFF1F5F9);
    String statusLabel = 'Chưa học';
    IconData statusIcon = Icons.lock_outline_rounded;

    if (isDone) {
      badgeColor = const Color(0xFF059669);
      badgeBg = const Color(0xFFECFDF5);
      statusLabel = 'Đã hoàn thành';
      statusIcon = Icons.check_circle_rounded;
    } else if (isInProgress) {
      badgeColor = const Color(0xFF2563EB);
      badgeBg = const Color(0xFFEFF6FF);
      statusLabel = 'Đang học';
      statusIcon = Icons.play_circle_fill_rounded;
    } else if (!isLocked) {
      badgeColor = const Color(0xFF0284C7);
      badgeBg = const Color(0xFFF0F9FF);
      statusLabel = 'Sẵn sàng học';
      statusIcon = Icons.play_circle_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone
              ? const Color(0xFFA7F3D0)
              : const Color(0xFFE2E8F0),
          width: isDone ? 1.4 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLocked
              ? null
              : () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _Lesson(
                        session: widget.session,
                        progress: Map<String, dynamic>.from(p),
                      ),
                    ),
                  );
                  await load();
                },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Lesson badge, demo tag, status chip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'BÀI ${lessonNumber.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: PartnerColors.primary,
                        ),
                      ),
                    ),
                    if (isDemo) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Video mẫu',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: badgeColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Title
                Text(
                  lesson['title']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isLocked ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 8),

                // Subtitle metadata strings (retains exact text expected by test)
                Text(
                  'Thời lượng: $durationSeconds giây\nĐã xem: $watchedSeconds/$durationSeconds giây · $status${isDemo ? ' · Video mẫu' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 12),

                // Watch progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: durationSeconds > 0
                        ? (watchedSeconds / durationSeconds).clamp(0.0, 1.0)
                        : 0.0,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDone ? const Color(0xFF10B981) : PartnerColors.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Action prompt button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      isLocked
                          ? 'Cần hoàn thành bài trước'
                          : isDone
                              ? 'Xem lại bài học →'
                              : 'Vào học ngay →',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isLocked
                            ? const Color(0xFF94A3B8)
                            : PartnerColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Lesson extends StatefulWidget {
  const _Lesson({required this.session, required this.progress});
  final Session session;
  final Map<String, dynamic> progress;

  @override
  State<_Lesson> createState() => _LessonState();
}

class _LessonState extends State<_Lesson> {
  VideoPlayerController? player;
  Timer? timer;
  late Map<String, dynamic> progress = widget.progress;
  String? error;
  int? answer;
  bool busy = false;

  Map<String, dynamic> get lesson =>
      Map<String, dynamic>.from(progress['lesson']);

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    try {
      final rawUrl = lesson['videoUrl'].toString();
      final managed = RegExp(r'^/api/v1/partner/training/videos/[0-9a-f-]{36}$')
          .hasMatch(rawUrl);
      final url = managed
          ? Uri.parse(widget.session.api.endpoint).resolve(rawUrl)
          : Uri.parse(rawUrl);
      final p = VideoPlayerController.networkUrl(
        url,
        httpHeaders: managed
            ? {'Authorization': 'Bearer ${widget.session.access}'}
            : const {},
      );
      player = p;
      await p.initialize();
      await p.seekTo(Duration(seconds: progress['positionSeconds'] ?? 0));
      await heartbeat();
      if (mounted) setState(() {});
      timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (player?.value.isPlaying == true && !busy) heartbeat();
      });
    } catch (e) {
      if (mounted) setState(() => error = 'Không phát được video: $e');
    }
  }

  Future<void> heartbeat() async {
    if (player == null) return;
    busy = true;
    try {
      final result = await widget.session.request(
        '/partner/training/lessons/${lesson['id']}/progress',
        method: 'POST',
        body: {'positionSeconds': player!.value.position.inSeconds},
      );
      if (mounted) {
        setState(() {
          progress = Map<String, dynamic>.from(result);
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      busy = false;
    }
  }

  Future<void> complete() async {
    if (answer == null || busy) return;
    await heartbeat();
    if (!mounted || error != null) return;
    setState(() => busy = true);
    try {
      final result = await widget.session.request(
        '/partner/training/lessons/${lesson['id']}/complete',
        method: 'POST',
        body: {'answer': answer},
      );
      if (mounted) {
        setState(() {
          progress = Map<String, dynamic>.from(result);
          error = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Chúc mừng! Bạn đã hoàn thành bài học.'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final durationSeconds = lesson['durationSeconds'] ?? 0;
    final watchedSeconds = progress['watchedSeconds'] ?? 0;
    final isDone = progress['status'] == 'COMPLETED';
    final quizText = lesson['quizText']?.toString() ?? 'Câu hỏi ôn tập';
    final quizOptions = (lesson['quizOptions'] as List?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          lesson['title']?.toString() ?? 'Chi tiết bài học',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (lesson['demo'] == true)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFD97706), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'VIDEO DEMO • nội dung minh họa',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),

          // Video Player Container
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: player?.value.isInitialized == true
                  ? Column(
                      children: [
                        AspectRatio(
                          aspectRatio: player!.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(player!),
                              // Center Play/Pause button
                              GestureDetector(
                                onTap: () async {
                                  if (player!.value.isPlaying) {
                                    await player!.pause();
                                    await heartbeat();
                                  } else {
                                    await player!.play();
                                  }
                                  if (mounted) setState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    player!.value.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        VideoProgressIndicator(
                          player!,
                          allowScrubbing: false,
                          colors: const VideoProgressColors(
                            playedColor: PartnerColors.primary,
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                tooltip: 'Phát / tạm dừng video',
                                onPressed: () async {
                                  if (player!.value.isPlaying) {
                                    await player!.pause();
                                    await heartbeat();
                                  } else {
                                    await player!.play();
                                  }
                                  if (mounted) setState(() {});
                                },
                                icon: Icon(
                                  player!.value.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${player!.value.position.inSeconds}s / ${durationSeconds}s',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text(
                              'Đang tải video bài giảng...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // Watched Progress card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thời lượng video: $durationSeconds giây',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Đã xem $watchedSeconds/$durationSeconds giây',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),

          const SizedBox(height: 20),

          // Knowledge Check / Quiz
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'CÂU HỎI ÔN TẬP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: PartnerColors.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isDone)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Đã hoàn thành bài học',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  quizText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),

                // 4 Options
                ...List.generate(
                  min(4, quizOptions.length),
                  (i) {
                    final isSelected = answer == i;
                    final optionLetter = String.fromCharCode(65 + i);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFEFF6FF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? PartnerColors.primary
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? PartnerColors.primary
                                : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              optionLetter,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          quizOptions[i].toString(),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        trailing: Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected
                              ? PartnerColors.primary
                              : const Color(0xFF94A3B8),
                        ),
                        onTap: () => setState(() => answer = i),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: busy || answer == null ? null : complete,
                    style: FilledButton.styleFrom(
                      backgroundColor: PartnerColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Nộp kiểm tra bài học',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
