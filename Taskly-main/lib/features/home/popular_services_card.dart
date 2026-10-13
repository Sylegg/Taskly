import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../shared/service_symbol.dart';
import 'home_components.dart' show HomeColors;

class PopularServicesCard extends StatefulWidget {
  const PopularServicesCard({
    super.key,
    required this.services,
    required this.onService,
  });
  final List<Service> services;
  final ValueChanged<String> onService;
  @override
  State<PopularServicesCard> createState() => _PopularServicesCardState();
}

class _PopularServicesCardState extends State<PopularServicesCard> {
  bool _canBack = false, _canForward = true;
  @override
  Widget build(BuildContext context) {
    final items = widget.services.where((s) => s.popular).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) =>
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    final m = notification.metrics;
                    final back = m.pixels > 1;
                    final forward = m.pixels < m.maxScrollExtent - 1;
                    if (back != _canBack || forward != _canForward) {
                      setState(() {
                        _canBack = back;
                        _canForward = forward;
                      });
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < items.length; i++)
                          SizedBox(
                            width:
                                constraints.maxWidth /
                                math.min(items.length, 4),
                            child: _PopularServiceTile(
                              key: ValueKey(items[i].id),
                              service: items[i],
                              index: i,
                              onTap: () => widget.onService(items[i].id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
          ),
          if (items.length > 4)
            _PopularScrollHint(canBack: _canBack, canForward: _canForward),
        ],
      ),
    );
  }
}

class _PopularServiceTile extends StatefulWidget {
  const _PopularServiceTile({
    super.key,
    required this.service,
    required this.index,
    required this.onTap,
  });
  final Service service;
  final int index;
  final VoidCallback onTap;
  @override
  State<_PopularServiceTile> createState() => _PopularServiceTileState();
}

class _PopularServiceTileState extends State<_PopularServiceTile>
    with TickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  late final _shine = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  bool _started = false, _pressed = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
      _shine.stop();
      _shine.value = 1;
    } else {
      if (!_started) _entrance.forward();
      if (!_shine.isAnimating) _shine.repeat();
    }
    _started = true;
  }

  @override
  void dispose() {
    _entrance.dispose();
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final start = math.min(widget.index, 4) * .09;
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(
          ((_entrance.value - start) / (1 - start)).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: .6 + .4 * progress,
          child: Transform.translate(
            offset: Offset(0, reduced ? 0 : 7 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: InkWell(
        key: ValueKey('popular-service-${widget.service.id}'),
        onTap: widget.onTap,
        onHighlightChanged: (v) => setState(() => _pressed = v),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            children: [
              AnimatedScale(
                scale: _pressed && !reduced ? .9 : 1,
                duration: Duration(milliseconds: reduced ? 0 : 180),
                curve: Curves.easeOutBack,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: Duration(milliseconds: reduced ? 0 : 180),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _pressed
                            ? const Color(0xFFC7EFE3)
                            : HomeColors.soft,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _pressed
                            ? [
                                BoxShadow(
                                  color: HomeColors.emerald.withValues(
                                    alpha: .18,
                                  ),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedBuilder(
                          animation: _shine,
                          builder: (context, child) {
                            final phase =
                                (_shine.value * 3 - widget.index * .16) % 1;
                            final shining =
                                !reduced && _shine.isAnimating && phase < .55;
                            final travel = phase / .55;
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                child!,
                                if (shining)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: Transform.translate(
                                        offset: Offset(-58 + 116 * travel, 0),
                                        child: Transform.rotate(
                                          angle: -.4,
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Color(0x00FFFFFF),
                                                  Color(0xB3FFFFFF),
                                                  Color(0x00FFFFFF),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (shining)
                                  Positioned(
                                    right: 3,
                                    top: 3,
                                    child: IgnorePointer(
                                      child: Opacity(
                                        opacity: math
                                            .sin(travel * math.pi)
                                            .clamp(0.0, 1.0),
                                        child: Transform.rotate(
                                          angle: travel * .8,
                                          child: const Icon(
                                            Icons.auto_awesome,
                                            size: 12,
                                            color: Color(0xFF09A98C),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                          child: Center(
                            child: ServiceSymbol.forService(
                              widget.service,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -5,
                      right: -10,
                      child: _PopularBadge(
                        animation: _shine,
                        index: widget.index,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.service.name,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: HomeColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopularBadge extends StatelessWidget {
  const _PopularBadge({required this.animation, required this.index});
  final Animation<double> animation;
  final int index;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final phase = MediaQuery.disableAnimationsOf(context)
            ? .5
            : (animation.value * 3 - index * .16) % 1;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFF1C45B), width: .7),
            gradient: LinearGradient(
              begin: Alignment(-1 + phase * 2, -1),
              end: Alignment(1 - phase * 2, 1),
              colors: const [
                Color(0xFFFFE494),
                Color(0xFFFFF9DC),
                Color(0xFFFFD66C),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFCA40)
                    .withValues(alpha: .12 + .12 * math.sin(phase * math.pi)),
                blurRadius: 5,
              ),
            ],
          ),
          child: const Text(
            'Phổ biến',
            style: TextStyle(
              fontSize: 7.5,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Color(0xFFA67409),
            ),
          ),
        );
      },
    ),
  );
}

class _PopularScrollHint extends StatefulWidget {
  const _PopularScrollHint({required this.canBack, required this.canForward});
  final bool canBack, canForward;
  @override
  State<_PopularScrollHint> createState() => _PopularScrollHintState();
}

class _PopularScrollHintState extends State<_PopularScrollHint>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _arrow(bool left, bool visible) => SizedBox(
    width: 24,
    child: visible
        ? AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Transform.translate(
              offset: Offset((left ? -1 : 1) * 5 * _controller.value, 0),
              child: Icon(
                left ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                size: 15,
                color: HomeColors.emerald,
              ),
            ),
          )
        : null,
  );
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, left: 6, right: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _arrow(true, widget.canBack),
        const Text(
          'Vuốt để xem thêm',
          style: TextStyle(fontSize: 10, color: HomeColors.muted),
        ),
        _arrow(false, widget.canForward),
      ],
    ),
  );
}
