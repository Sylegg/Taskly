import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../auth/api.dart';
import 'task_chat.dart';

bool needsCustomerConfirmation(Map task) =>
    const ['COMPLETED', 'PAID'].contains(task['status']) &&
    task['customerConfirmedAt'] == null;

bool isCustomerHistoryTask(Map task) =>
    const [
      'COMPLETED',
      'PAID',
      'CANCELLED',
      'EXPIRED',
      'REFUNDED',
    ].contains(task['status']) &&
    !needsCustomerConfirmation(task);

/// A short pulse draws attention once; reduced motion keeps a static highlight.
class CompletionAttention extends StatefulWidget {
  const CompletionAttention({
    super.key,
    required this.onPressed,
    this.iconOnly = false,
  });
  final bool iconOnly;
  final VoidCallback onPressed;
  @override
  State<CompletionAttention> createState() => _CompletionAttentionState();
}

class _CompletionAttentionState extends State<CompletionAttention>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _stop;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _stop?.cancel();
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_started) {
      _started = true;
      _pulse.repeat(reverse: true);
      _stop = Timer(const Duration(milliseconds: 5400), () {
        if (mounted) _pulse.animateTo(0);
      });
    }
  }

  @override
  void dispose() {
    _stop?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.iconOnly
      ? AnimatedBuilder(
          animation: _pulse,
          builder: (_, _) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(16, 185, 129, .12 * _pulse.value),
                  blurRadius: 6 * _pulse.value,
                ),
              ],
            ),
            child: IconButton(
              key: const ValueKey('customer-completion-action'),
              tooltip: 'Xem ảnh & xác nhận',
              onPressed: widget.onPressed,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: const EdgeInsets.all(7),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: const Color(0xFFD1FAE5),
                foregroundColor: const Color(0xFF047857),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: const Icon(Icons.photo_library_outlined, size: 19),
            ),
          ),
        )
      : AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Container(
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0AAF83), Color(0xFF009B72)],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: Color.fromRGBO(16, 185, 129, .08 + .08 * _pulse.value),
                  blurRadius: 4 + 4 * _pulse.value,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: child,
          ),
          child: Tooltip(
            message: 'Xem ảnh & xác nhận',
            child: Material(
              key: const ValueKey('customer-completion-action'),
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(13),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 17,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Xem ảnh & xác nhận',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
}

class CompletionReviewScreen extends StatefulWidget {
  const CompletionReviewScreen({
    super.key,
    required this.session,
    required this.taskId,
  });
  final Session session;
  final String taskId;
  @override
  State<CompletionReviewScreen> createState() => _CompletionReviewScreenState();
}

class _CompletionReviewScreenState extends State<CompletionReviewScreen> {
  Map<String, dynamic>? _detail;
  String? _error;
  bool _sending = false;
  bool _checked = false;
  int _photo = 0;
  final _viewed = <int>{};
  final _pages = PageController();
  List<Map> get _photos => ((_detail?['messages'] as List?) ?? [])
      .whereType<Map>()
      .where(
        (m) =>
            m['mine'] != true &&
            m['text'] ==
                'Ảnh xác nhận khu vực đã hoàn thành theo yêu cầu khách hàng' &&
            (m['imageData']?.toString().isNotEmpty ?? false),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final detail = await widget.session.request(
        '/task-activity/${widget.taskId}',
      );
      if (!mounted) return;
      setState(() {
        _detail = Map<String, dynamic>.from(detail);
        _viewed.clear();
        _photo = 0;
        _checked = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _confirm() async {
    if (_sending ||
        !_checked ||
        _viewed.length != _photos.length ||
        _photos.length < 2) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.session.request(
        '/task-activity/${widget.taskId}/confirm-completion',
        method: 'POST',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xác nhận hoàn thành. Đơn đã chuyển vào lịch sử.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _image(Map photo, int index) {
    try {
      final raw = photo['imageData'].toString();
      return Image.memory(
        base64Decode(raw.substring(raw.indexOf(',') + 1)),
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, synchronous) {
          if ((frame != null || synchronous) && !_viewed.contains(index)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _photo == index) {
                setState(() => _viewed.add(index));
              }
            });
          }
          return child;
        },
        errorBuilder: (_, _, _) => const Center(
          child: Text('Không tải được ảnh. Vui lòng nhắn đối tác gửi lại.'),
        ),
      );
    } catch (_) {
      return const Center(
        child: Text('Ảnh không hợp lệ. Vui lòng nhắn đối tác gửi lại.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    final task = _detail?['task'] as Map?;
    final pending = task != null && needsCustomerConfirmation(task);
    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận hoàn thành')),
      body: _detail == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    task?['serviceName'] ?? 'Dịch vụ',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pending
                        ? 'Xem ảnh các khu vực đối tác đã thực hiện trước khi xác nhận.'
                        : 'Đơn đã được xác nhận hoặc không còn chờ xác nhận.',
                  ),
                  const SizedBox(height: 16),
                  if (photos.isNotEmpty) ...[
                    Text(
                      'Ảnh ${_photo + 1}/${photos.length} · Đã xem ${_viewed.length}/${photos.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 300,
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: photos.length,
                        onPageChanged: (index) =>
                            setState(() => _photo = index),
                        itemBuilder: (_, index) => InteractiveViewer(
                          child: _image(photos[index], index),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: _photo > 0
                              ? () => _pages.previousPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                )
                              : null,
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Ảnh trước'),
                        ),
                        TextButton.icon(
                          onPressed: _photo < photos.length - 1
                              ? () => _pages.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                )
                              : null,
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('Ảnh tiếp'),
                        ),
                      ],
                    ),
                  ] else
                    const Text(
                      'Chưa có ảnh hoàn thành. Vui lòng nhắn đối tác bổ sung ảnh.',
                    ),
                  if (pending) ...[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _checked,
                      onChanged:
                          !_sending &&
                              photos.length >= 2 &&
                              _viewed.length == photos.length
                          ? (value) => setState(() => _checked = value == true)
                          : null,
                      title: const Text(
                        'Tôi đã kiểm tra ảnh và công việc đã hoàn thành đúng yêu cầu.',
                      ),
                    ),
                    if (_viewed.length < photos.length)
                      const Text(
                        'Vui lòng xem tất cả ảnh để tiếp tục.',
                        style: TextStyle(color: Color(0xFF047857)),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _sending || !_checked ? null : _confirm,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _sending ? 'Đang xác nhận…' : 'Xác nhận hoàn thành',
                      ),
                    ),
                  ],
                  TextButton.icon(
                    onPressed: _sending
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TaskChatScreen(
                                session: widget.session,
                                taskId: widget.taskId,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Cần trao đổi? Nhắn đối tác'),
                  ),
                ],
              ),
            ),
    );
  }
}
