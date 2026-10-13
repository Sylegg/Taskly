import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/api.dart';

class TaskArrivalReport extends StatefulWidget {
  const TaskArrivalReport({
    super.key,
    required this.session,
    required this.taskId,
    required this.scheduledAt,
    this.waitingForTasker = false,
  });
  final Session session;
  final String taskId;
  final String? scheduledAt;
  final bool waitingForTasker;
  @override
  State<TaskArrivalReport> createState() => _TaskArrivalReportState();
}

class _TaskArrivalReportState extends State<TaskArrivalReport> {
  Timer? _timer;
  StreamSubscription<void>? _live;
  final _elapsed = Stopwatch();
  Duration? _remaining;
  bool _reported = false,
      _eligible = false,
      _sending = false,
      _loading = false,
      _visible = false;
  String _type = 'LATE_ARRIVAL';
  int _ticks = 0;
  bool get _beforeAppointment {
    final scheduled = DateTime.tryParse(widget.scheduledAt ?? '');
    return scheduled == null || DateTime.now().isBefore(scheduled);
  }

  @override
  void initState() {
    super.initState();
    _load();
    _live = widget.session.liveChanges.listen((_) => _load());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_beforeAppointment) return;
      setState(() {});
      if (++_ticks % 10 == 0) _load();
    });
  }

  @override
  void didUpdateWidget(covariant TaskArrivalReport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId ||
        oldWidget.waitingForTasker != widget.waitingForTasker ||
        oldWidget.scheduledAt != widget.scheduledAt) {
      _visible = false;
      _remaining = null;
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading || _sending || _beforeAppointment) return;
    _loading = true;
    final id = widget.taskId;
    final waiting = widget.waitingForTasker;
    try {
      final state = await widget.session.request(
        '/task-activity/$id/arrival-report',
      ) as Map;
      if (!mounted || id != widget.taskId || waiting != widget.waitingForTasker) {
        return;
      }
      setState(() {
        _reported = state['reported'] == true;
        _eligible = state['eligible'] == true;
        _visible = state['visible'] == true;
        _type = state['reportType']?.toString() ?? 'LATE_ARRIVAL';
        _remaining = state['reportAvailableAt'] == null
            ? null
            : DateTime.parse(state['reportAvailableAt'])
                  .difference(DateTime.parse(state['serverNow']));
        _elapsed
          ..reset()
          ..start();
      });
    } catch (_) {
      // Keep the countdown and retry automatically on the next refresh.
    } finally {
      _loading = false;
    }
  }

  Future<void> _report() async {
    if (_sending || !_eligible) return;
    setState(() => _sending = true);
    try {
      await widget.session.request(
        '/task-activity/${widget.taskId}/arrival-report',
        method: 'POST',
      );
      if (mounted) {
        setState(() {
          _reported = true;
          _eligible = false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa gửi được báo cáo. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _live?.cancel();
    _elapsed.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_beforeAppointment || !_visible || _remaining == null) {
      return const SizedBox.shrink();
    }
    final seconds = ((_remaining! - _elapsed.elapsed).inMilliseconds / 1000)
        .ceil()
        .clamp(0, 1800);
    final waiting = _type == 'NO_TASKER';
    final overdue = seconds == 0;
    final text = _reported
        ? 'Đã gửi báo cáo cho admin. Theo dõi phản hồi tại Hỗ trợ → Chăm sóc khách hàng.'
        : overdue
        ? waiting
              ? 'Đã quá 30 phút nhưng chưa có Tasker nhận việc.'
              : 'Đã quá 30 phút chờ Tasker đến. Nếu Tasker chưa tới, bạn có thể báo cáo.'
        : '${waiting ? 'Đang tìm Tasker' : 'Đang chờ Tasker đến'} • ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: overdue && !_reported
            ? const Color(0xFFFFF7ED)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: overdue && !_reported
                  ? const Color(0xFFC2410C)
                  : const Color(0xFF475569),
            ),
          ),
          if (overdue && _eligible && !_reported)
            OutlinedButton.icon(
              onPressed: _sending ? null : _report,
              icon: const Icon(Icons.report_problem_outlined),
              label: Text(
                _sending
                    ? 'Đang gửi…'
                    : waiting
                    ? 'Báo cáo chưa có Tasker nhận việc'
                    : 'Báo cáo Tasker chưa tới',
              ),
            ),
        ],
      ),
    );
  }
}
