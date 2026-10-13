import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../auth/api.dart';

class CommunityReels extends StatefulWidget {
  const CommunityReels({
    super.key,
    required this.session,
    this.query = '',
    this.bottomPadding = 0,
  });

  final Session session;
  final String query;
  final double bottomPadding;

  @override
  State<CommunityReels> createState() => _CommunityReelsState();
}

class _CommunityReelsState extends State<CommunityReels> {
  List<dynamic>? videos;
  String? error;
  int current = 0;

  @override
  void didUpdateWidget(covariant CommunityReels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) current = 0;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.session.request('/public/community-videos');
      if (mounted) {
        setState(() {
          videos = result as List;
          error = null;
          current = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 40),
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Thử lại'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F9D7A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (videos == null) {
      return Container(
        color: const Color(0xFF0F172A),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF0F9D7A)),
        ),
      );
    }

    final items = videos!
        .where(
          (v) => '${v['caption']} ${v['hashtag']}'.toLowerCase().contains(
            widget.query.toLowerCase(),
          ),
        )
        .toList();

    if (items.isEmpty) {
      return Container(
        color: const Color(0xFF0F172A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.video_library_outlined,
                  size: 48,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.query.isEmpty
                    ? 'Chưa có video ngắn nào.'
                    : 'Không tìm thấy video phù hợp.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Video mới sẽ sớm được cập nhật trên TaskLy.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Tải lại danh sách'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0F9D7A),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PageView.builder(
      key: ValueKey(widget.query),
      scrollDirection: Axis.vertical,
      allowImplicitScrolling: true,
      itemCount: items.length,
      onPageChanged: (index) => setState(() => current = index),
      itemBuilder: (context, index) => _Reel(
        key: ValueKey(items[index]['id']),
        video: items[index],
        session: widget.session,
        url: widget.session.api.publicAssetUrl(items[index]['videoUrl']),
        active: index == current,
        keepWarm: (index - current).abs() <= 1,
        bottomPadding: widget.bottomPadding,
      ),
    );
  }
}

class _Reel extends StatefulWidget {
  const _Reel({
    super.key,
    required this.video,
    required this.url,
    required this.active,
    required this.keepWarm,
    required this.session,
    this.bottomPadding = 0,
  });

  final dynamic video;
  final String url;
  final bool active;
  final bool keepWarm;
  final Session session;
  final double bottomPadding;

  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin {
  late final VideoPlayerController player;
  String? error;
  bool liked = false, liking = false;
  int? likes;
  bool viewSent = false;
  bool showHeartAnim = false;
  bool showPlayPauseIcon = false;
  bool isPlaying = true;
  bool expandedCaption = false;
  bool userPaused = false;
  bool foreground = true;

  @override
  bool get wantKeepAlive => widget.keepWarm;

  late final AnimationController _discAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _discAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    player = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    player.addListener(recordView);
    initialize();
    loadLikes();
  }

  void recordView() {
    if (viewSent ||
        !widget.active ||
        !player.value.isPlaying ||
        player.value.position < const Duration(seconds: 3)) {
      return;
    }
    viewSent = true;
    widget.session
        .request('/community/videos/${widget.video['id']}/view', method: 'POST')
        .catchError((Object _) {
          viewSent = false;
          return null;
        });
  }

  Future<void> loadLikes() async {
    try {
      final result = await widget.session.request(
        '/community/videos/${widget.video['id']}/likes',
      );
      if (mounted) {
        setState(() {
          liked = result['liked'] == true;
          likes = result['likes'];
        });
      }
    } catch (_) {}
  }

  Future<void> like({bool onlyLike = false}) async {
    if (liking || (onlyLike && liked)) return;
    setState(() => liking = true);
    try {
      final result = await widget.session.request(
        '/community/videos/${widget.video['id']}/likes',
        method: 'PUT',
        body: {'liked': onlyLike || !liked},
      );
      if (mounted) {
        setState(() {
          liked = result['liked'] == true;
          likes = result['likes'];
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lưu lượt thích. Hãy thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => liking = false);
    }
  }

  void onDoubleTapLike() {
    like(onlyLike: true);
    setState(() => showHeartAnim = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => showHeartAnim = false);
    });
  }

  void togglePlayPause() {
    if (!player.value.isInitialized || !widget.active || !foreground) return;
    setState(() {
      if (player.value.isPlaying) {
        player.pause();
        isPlaying = false;
        userPaused = true;
        _discAnim.stop();
      } else {
        player.play();
        isPlaying = true;
        userPaused = false;
        _discAnim.repeat();
      }
      showPlayPauseIcon = true;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => showPlayPauseIcon = false);
    });
  }

  Future<void> initialize() async {
    try {
      await player.initialize();
      if (!mounted) return;
      await player.setLooping(true);
      if (widget.active && foreground && !userPaused) {
        await player.play();
        isPlaying = true;
        if (mounted && widget.active && foreground && !userPaused) {
          _discAnim.repeat();
        } else {
          await player.pause();
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => error = 'Không thể phát video.');
    }
  }

  @override
  void didUpdateWidget(covariant _Reel old) {
    super.didUpdateWidget(old);
    if (old.keepWarm != widget.keepWarm) updateKeepAlive();
    if (old.active == widget.active) return;
    if (player.value.isInitialized) {
      if (widget.active && foreground && !userPaused) {
        player.play();
        isPlaying = true;
        _discAnim.repeat();
      } else {
        player.pause();
        isPlaying = false;
        _discAnim.stop();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) {
      player.pause();
      _discAnim.stop();
    } else if (widget.active && !userPaused && player.value.isInitialized) {
      player.play();
      _discAnim.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _discAnim.dispose();
    player.removeListener(recordView);
    player.dispose();
    super.dispose();
  }

  String formatLikes(int? count) {
    if (count == null || count <= 0) return '0';
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildReel(context);
  }

  Widget _buildReel(BuildContext context) => ColoredBox(
    color: const Color(0xFF0F172A),
    child: Stack(
      fit: StackFit.expand,
      children: [
        // Video presentation
        if (error != null)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 48),
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          )
        else if (!player.value.isInitialized)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF0F9D7A)),
          )
        else
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: onDoubleTapLike,
            onTap: togglePlayPause,
            child: Center(
              child: AspectRatio(
                aspectRatio: player.value.aspectRatio,
                child: VideoPlayer(player),
              ),
            ),
          ),

        // Double-tap heart animation
        if (showHeartAnim)
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.2),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x66FF2D55),
                        blurRadius: 32,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 96,
                    color: Color(0xFFFF2D55),
                  ),
                ),
              ),
            ),
          ),

        // Play/Pause tap feedback
        if (showPlayPauseIcon)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),

        // Top-to-bottom soft gradient for status bar visibility
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 90,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom gradient scrim for high readability
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 240,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Right Action Bar (Modern Social Vertical Rail)
        Positioned(
          right: 12,
          bottom: widget.bottomPadding > 0 ? widget.bottomPadding + 28 : 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Creator avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F9D7A), Color(0xFF087A60)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'T',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Like button
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: liked ? 'Bỏ thích' : 'Thả tim',
                    onPressed: liking ? null : () => like(),
                    icon: Icon(
                      liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 32,
                      color: liked ? const Color(0xFFFF2D55) : Colors.white,
                    ),
                  ),
                  Text(
                    formatLikes(likes),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Share button
              IconButton(
                tooltip: 'Chia sẻ video',
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text:
                          '${widget.video['caption']}\n${widget.session.api.publicAssetUrl(widget.video['videoUrl'])}',
                    ),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Đã sao chép liên kết video ngắn.'),
                          ],
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(
                  Icons.share_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Rotating music vinyl disc
              RotationTransition(
                turns: _discAnim,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 6),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.music_note_rounded, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom Left Information Overlay
        Positioned(
          left: 16,
          right: 76,
          bottom: widget.bottomPadding > 0 ? widget.bottomPadding + 14 : 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Creator handle & verified check
              Row(
                children: [
                  const Text(
                    'TaskLy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F9D7A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 10, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Chính thức',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Caption with clean expand toggle
              if (widget.video['caption'] != null &&
                  widget.video['caption'].toString().isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => expandedCaption = !expandedCaption),
                  child: Text(
                    widget.video['caption'],
                    maxLines: expandedCaption ? 6 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ),

              // Hashtag pill
              if (widget.video['hashtag'] != null &&
                  widget.video['hashtag'].toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    widget.video['hashtag'].toString().startsWith('#')
                        ? widget.video['hashtag']
                        : '#${widget.video['hashtag']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // Audio track indicator
              Row(
                children: [
                  const Icon(
                    Icons.music_note_rounded,
                    size: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Âm thanh gốc • TaskLy Studio',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Slim video progress indicator right at the bottom menu boundary
        if (player.value.isInitialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.bottomPadding > 0 ? widget.bottomPadding : 0,
            child: VideoProgressIndicator(
              player,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 2),
              colors: VideoProgressColors(
                playedColor: const Color(0xFF0F9D7A),
                bufferedColor: Colors.white.withValues(alpha: 0.35),
                backgroundColor: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
      ],
    ),
  );
}
