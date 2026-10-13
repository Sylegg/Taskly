import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../auth/api.dart';
import 'task_chat.dart';
import 'service_unavailable.dart';
import 'task_arrival_report.dart';

String activityStatus(String value) => switch (value) {
  'POSTED' => 'Đã đặt dịch vụ',
  'MATCHING' => 'Đang tìm Tasker',
  'ACCEPTED' => 'Tasker đã nhận việc',
  'TASKER_ON_THE_WAY' => 'Tasker đang đến',
  'ARRIVED' => 'Tasker đã đến',
  'IN_PROGRESS' => 'Đang thực hiện',
  'COMPLETED' => 'Đã hoàn thành',
  'PAID' => 'Đã thanh toán',
  'CANCELLED' => 'Đã hủy',
  'EXPIRED' => 'Đã hết hạn',
  'DISPUTED' => 'Đang xử lý sự cố',
  'REFUNDED' => 'Đã hoàn tiền',
  _ => value,
};

String _pad2(int n) => n.toString().padLeft(2, '0');

DateTime? _parseDt(dynamic v) {
  if (v == null) return null;
  try {
    return DateTime.parse(v.toString()).toLocal();
  } catch (_) {
    return null;
  }
}

String _formatDateTime(dynamic v) {
  final dt = _parseDt(v);
  if (dt == null) return '--:--';
  return '${_pad2(dt.hour)}:${_pad2(dt.minute)}, ${_pad2(dt.day)}/${_pad2(dt.month)}/${dt.year}';
}

String _formatTimelineTime(dynamic v) {
  final dt = _parseDt(v);
  if (dt == null) return '';
  final now = DateTime.now();
  final isToday =
      dt.year == now.year && dt.month == now.month && dt.day == now.day;
  final yesterday = now.subtract(const Duration(days: 1));
  final isYesterday =
      dt.year == yesterday.year &&
      dt.month == yesterday.month &&
      dt.day == yesterday.day;

  final timeStr = '${_pad2(dt.hour)}:${_pad2(dt.minute)}';
  if (isToday) {
    return 'Hôm nay, $timeStr';
  } else if (isYesterday) {
    return 'Hôm qua, $timeStr';
  } else {
    return '$timeStr · ${_pad2(dt.day)}/${_pad2(dt.month)}/${dt.year}';
  }
}

String _formatCurrency(dynamic value) {
  if (value == null) return '0 đ';
  final num val = value is num ? value : (num.tryParse(value.toString()) ?? 0);
  final str = val.toInt().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(str[i]);
  }
  return '${buffer.toString()} đ';
}

class ActivityStatusConfig {
  final String label;
  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;

  const ActivityStatusConfig({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
    required this.icon,
  });
}

ActivityStatusConfig getStatusConfig(String status) {
  switch (status) {
    case 'POSTED':
      return const ActivityStatusConfig(
        label: 'Đã đặt dịch vụ',
        foreground: Color(0xFF0369A1),
        background: Color(0xFFF0F9FF),
        border: Color(0xFFBAE6FD),
        icon: Icons.assignment_turned_in_outlined,
      );
    case 'MATCHING':
      return const ActivityStatusConfig(
        label: 'Đang tìm Tasker',
        foreground: Color(0xFFD97706),
        background: Color(0xFFFFFBEB),
        border: Color(0xFFFDE68A),
        icon: Icons.person_search_outlined,
      );
    case 'ACCEPTED':
      return const ActivityStatusConfig(
        label: 'Tasker đã nhận việc',
        foreground: Color(0xFF059669),
        background: Color(0xFFECFDF5),
        border: Color(0xFFA7F3D0),
        icon: Icons.how_to_reg_outlined,
      );
    case 'TASKER_ON_THE_WAY':
      return const ActivityStatusConfig(
        label: 'Tasker đang đến',
        foreground: Color(0xFF0284C7),
        background: Color(0xFFF0F9FF),
        border: Color(0xFFBAE6FD),
        icon: Icons.directions_bike_outlined,
      );
    case 'ARRIVED':
      return const ActivityStatusConfig(
        label: 'Tasker đã đến',
        foreground: Color(0xFF4F46E5),
        background: Color(0xFFEEF2FF),
        border: Color(0xFFC7D2FE),
        icon: Icons.location_on_outlined,
      );
    case 'IN_PROGRESS':
      return const ActivityStatusConfig(
        label: 'Đang thực hiện',
        foreground: Color(0xFF0D9488),
        background: Color(0xFFF0FDFA),
        border: Color(0xFF99F6E4),
        icon: Icons.handyman_outlined,
      );
    case 'COMPLETED':
      return const ActivityStatusConfig(
        label: 'Đã hoàn thành',
        foreground: Color(0xFF16A34A),
        background: Color(0xFFF0FDF4),
        border: Color(0xFFBBF7D0),
        icon: Icons.check_circle_outline_rounded,
      );
    case 'PAID':
      return const ActivityStatusConfig(
        label: 'Đã thanh toán',
        foreground: Color(0xFF059669),
        background: Color(0xFFECFDF5),
        border: Color(0xFFA7F3D0),
        icon: Icons.verified_outlined,
      );
    case 'CANCELLED':
      return const ActivityStatusConfig(
        label: 'Đã hủy',
        foreground: Color(0xFFDC2626),
        background: Color(0xFFFEF2F2),
        border: Color(0xFFFECACA),
        icon: Icons.cancel_outlined,
      );
    case 'EXPIRED':
      return const ActivityStatusConfig(
        label: 'Đã hết hạn',
        foreground: Color(0xFF64748B),
        background: Color(0xFFF8FAFC),
        border: Color(0xFFE2E8F0),
        icon: Icons.timer_off_outlined,
      );
    case 'REFUNDED':
      return const ActivityStatusConfig(
        label: 'Đã hoàn tiền',
        foreground: Color(0xFF0284C7),
        background: Color(0xFFF0F9FF),
        border: Color(0xFFBAE6FD),
        icon: Icons.currency_exchange_rounded,
      );
    default:
      return ActivityStatusConfig(
        label: activityStatus(status),
        foreground: const Color(0xFF475569),
        background: const Color(0xFFF1F5F9),
        border: const Color(0xFFCBD5E1),
        icon: Icons.info_outline,
      );
  }
}

Widget _buildStatusBadge(String status) {
  final cfg = getStatusConfig(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: cfg.background,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: cfg.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(cfg.icon, size: 14, color: cfg.foreground),
        const SizedBox(width: 5),
        Text(
          cfg.label,
          style: TextStyle(
            color: cfg.foreground,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class TaskActivityList extends StatefulWidget {
  const TaskActivityList({
    super.key,
    required this.session,
    this.partner = false,
    this.preview = false,
    this.showHeading = true,
    this.filter,
    this.emptyWidget,
  });
  final Session session;
  final bool partner;
  final bool preview;
  final bool showHeading;
  final bool Function(Map<String, dynamic>)? filter;
  final Widget? emptyWidget;
  @override
  State<TaskActivityList> createState() => _TaskActivityListState();
}

class _TaskActivityListState extends State<TaskActivityList> {
  StreamSubscription<void>? _liveSubscription;
  bool _refreshing = false;
  @override
  void initState() {
    super.initState();
    _liveSubscription = widget.session.liveChanges.listen(
      (_) => _refreshLive(),
    );
  }

  Future<void> _refreshLive() async {
    if (_refreshing || !mounted) return;
    _refreshing = true;
    try {
      final items = await _load();
      if (mounted)
        setState(() {
          _items = Future.value(items);
        });
    } catch (_) {
      /* Retain the last list while offline. */
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }

  late Future<dynamic> _items = _load();
  Future<dynamic> _load() => widget.session.request(
    widget.partner ? '/task-activity?partner=true' : '/task-activity',
  );
  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _items,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return Column(
          children: [
            const Text('Không thể tải công việc.'),
            TextButton(
              onPressed: () => setState(() {
                _items = _load();
              }),
              child: const Text('Thử lại'),
            ),
          ],
        );
      }
      final items = (snapshot.data as List)
          .where(
            (task) =>
                widget.filter?.call(Map<String, dynamic>.from(task)) ?? true,
          )
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeading)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Công việc của bạn',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tải lại hoạt động',
                  onPressed: () => setState(() {
                    _items = _load();
                  }),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          if (widget.showHeading)
            Text(
              widget.partner
                  ? 'Theo dõi tiến trình và trò chuyện với khách hàng.'
                  : 'Theo dõi tiến trình và trò chuyện với Tasker của từng công việc.',
              style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
            ),
          if (widget.showHeading) const SizedBox(height: 16),
          if (items.isEmpty)
            widget.emptyWidget ??
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Text(
                      widget.partner
                          ? 'Chưa có công việc.'
                          : 'Chưa có công việc đã đặt.',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
          for (final task in items)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskActivityDetail(
                        session: widget.session,
                        id: task['id'],
                        partner: widget.partner,
                      ),
                    ),
                  );
                  if (mounted)
                    setState(() {
                      _items = _load();
                    });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: widget.partner
                                  ? const Color(0xFFEFF6FF)
                                  : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: widget.partner
                                    ? const Color(0xFFBFDBFE)
                                    : const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: Icon(
                              Icons.receipt_long_outlined,
                              color: widget.partner
                                  ? const Color(0xFF1E5BF8)
                                  : const Color(0xFF059669),
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task['serviceName'] ?? 'Dịch vụ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                if (task['scheduledAt'] != null)
                                  Text(
                                    'Hẹn: ${_formatDateTime(task['scheduledAt'])}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _buildStatusBadge(task['status'] ?? ''),
                        ],
                      ),
                      if (!widget.partner &&
                          [
                            'POSTED',
                            'MATCHING',
                            'TASKER_ON_THE_WAY',
                          ].contains(task['status']))
                        TaskArrivalReport(
                          session: widget.session,
                          taskId: task['id'].toString(),
                          scheduledAt: task['scheduledAt']?.toString(),
                          waitingForTasker: task['taskerId'] == null,
                        ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              task['taskerId'] == null
                                  ? Icons.person_search_outlined
                                  : Icons.person_outline_rounded,
                              size: 16,
                              color: const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.partner
                                    ? 'Khách hàng: ${task['customerName'] ?? 'Chưa cập nhật'}'
                                    : (task['taskerId'] == null
                                          ? 'Chưa có Tasker nhận việc'
                                          : 'Tasker: ${task['taskerName'] ?? 'Tasker'}'),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatCurrency(
                                widget.partner
                                    ? (task['partnerNetAmount'] ?? 0)
                                    : (task['budgetAmount'] ?? 0),
                              ),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: widget.partner
                                    ? const Color(0xFF1E5BF8)
                                    : const Color(0xFF059669),
                              ),
                            ),
                            if (task['taskerId'] != null || widget.partner) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => TaskChatScreen(
                                        session: widget.session,
                                        taskId: task['id'],
                                        partner: widget.partner,
                                        initialTaskerName: task['taskerName'],
                                        initialCustomerName:
                                            task['customerName'],
                                        initialServiceName: task['serviceName'],
                                      ),
                                    ),
                                  );
                                  if (mounted) {
                                    setState(() {
                                      _items = _load();
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.partner
                                        ? const Color(0xFFEFF6FF)
                                        : const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: widget.partner
                                          ? const Color(0xFFBFDBFE)
                                          : const Color(0xFFA7F3D0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        size: 14,
                                        color: widget.partner
                                            ? const Color(0xFF1E5BF8)
                                            : const Color(0xFF059669),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Chat',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: widget.partner
                                              ? const Color(0xFF1E5BF8)
                                              : const Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: Color(0xFF94A3B8),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      );
    },
  );
}

class TaskActivityDetail extends StatefulWidget {
  const TaskActivityDetail({
    super.key,
    required this.session,
    required this.id,
    this.onBack,
    this.partner = false,
    this.preview = false,
  });
  final Session session;
  final String id;
  final VoidCallback? onBack;
  final bool partner;
  final bool preview;
  @override
  State<TaskActivityDetail> createState() => _TaskActivityDetailState();
}

class _TaskActivityDetailState extends State<TaskActivityDetail>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  Map<String, dynamic>? _detail;
  String? _error;
  bool _loading = false;
  bool _viewRecorded = false;
  bool _serviceUnavailable = false;
  bool _progressing = false;

  Future<void> _progress(String current, String next) async {
    if (next == 'COMPLETED') {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskChatScreen(
        session: widget.session, taskId: widget.id, partner: true, completionMode: true,
      )));
      if (mounted) await _load();
      return;
    }
    setState(() => _progressing = true);
    try {
      await widget.session.request(
        '/partner/jobs/${widget.id}/status',
        method: 'POST',
        body: {
          'expectedStatus': current,
          'status': next,
          'requestId': 'job-${widget.id}-$next',
        },
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _progressing = false);
    }
  }

  Future<void> _checkIn() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskChatScreen(
          session: widget.session,
          taskId: widget.id,
          partner: true,
          checkInMode: true,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _startJob() async {
    setState(() => _progressing = true);
    try {
      await widget.session.request(
        '/partner/jobs/${widget.id}/start',
        method: 'POST',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bắt đầu công việc thành công! Thời gian làm thật đã được ghi nhận.',
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        final msg = e is ApiFailure ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _progressing = false);
    }
  }

  Future<void> _customerDecision(String requestId, String decision) async {
    setState(() => _progressing = true);
    try {
      await widget.session.request(
        '/customer/bookings/${widget.id}/early-start-requests/$requestId/decision',
        method: 'POST',
        body: {'decision': decision},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == 'APPROVE'
                  ? 'Đã chấp thuận cho Đối tác bắt đầu sớm.'
                  : 'Đã giữ nguyên lịch hẹn đã đặt.',
            ),
            backgroundColor: decision == 'APPROVE'
                ? const Color(0xFF10B981)
                : const Color(0xFF64748B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        final msg = e is ApiFailure ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _progressing = false);
    }
  }

  Future<void> _showEarlyStartDialog(
    DateTime scheduledDt,
    int durationMinutes,
  ) async {
    final eligibility = (_detail?['earlyStart'] as Map?) ?? {};
    final openedAt = DateTime.now();
    final serverNow = _parseDt(eligibility['serverNow']) ?? openedAt;
    DateTime currentTime() =>
        serverNow.add(DateTime.now().difference(openedAt));
    final maxEarlyMinutes =
        (eligibility['maxEarlyStartMinutes'] as num?)?.toInt() ?? 60;
    final earliest = scheduledDt.subtract(Duration(minutes: maxEarlyMinutes));
    final firstAllowed = earliest.isAfter(currentTime())
        ? earliest
        : currentTime();
    var selectedStart = DateTime(
      firstAllowed.year,
      firstAllowed.month,
      firstAllowed.day,
      firstAllowed.hour,
      firstAllowed.minute,
    ).add(const Duration(minutes: 1));
    bool validStart(DateTime value) =>
        !value.isBefore(currentTime()) &&
        !value.isBefore(earliest) &&
        value.isBefore(scheduledDt);

    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final reqStart = selectedStart;
          final propEnd = reqStart.add(Duration(minutes: durationMinutes));

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Xin bắt đầu sớm',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bạn có thể xin bắt đầu công việc sớm hơn giờ khách đặt. Khách hàng phải đồng ý trong ứng dụng thì bạn mới được bắt đầu làm sớm.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hiện tại: ${_formatDateTime(currentTime().toIso8601String())}',
                  ),
                  Text(
                    'Lịch hẹn của đơn: ${_formatDateTime(scheduledDt.toIso8601String())}',
                  ),
                  Text('Có thể đề nghị sớm tối đa $maxEarlyMinutes phút.'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      _formatDateTime(selectedStart.toIso8601String()),
                    ),
                    onPressed: () async {
                      final lower = earliest.isAfter(currentTime())
                          ? earliest
                          : currentTime();
                      if (!lower.isBefore(scheduledDt)) return;
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: selectedStart.isBefore(lower)
                            ? lower
                            : selectedStart,
                        firstDate: lower,
                        lastDate: scheduledDt,
                      );
                      if (date == null || !ctx.mounted) return;
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(selectedStart),
                      );
                      if (time == null || !ctx.mounted) return;
                      final candidate = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                      if (!validStart(candidate)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Chọn giờ từ hiện tại, trước lịch hẹn và trong giới hạn làm sớm.',
                            ),
                          ),
                        );
                        return;
                      }
                      setDlgState(() => selectedStart = candidate);
                    },
                  ),
                  const Text(
                    'Chọn thời gian đề nghị bắt đầu sớm:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [15, 30, 45, 60].map((mins) {
                      final proposed = scheduledDt.subtract(
                        Duration(minutes: mins),
                      );
                      final isSel = selectedStart.isAtSameMomentAs(proposed);
                      final timeStr = _formatDateTime(
                        proposed.toIso8601String(),
                      );
                      return ChoiceChip(
                        label: Text('$mins phút ($timeStr)'),
                        selected: isSel,
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : const Color(0xFF334155),
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12,
                        ),
                        onSelected: validStart(proposed)
                            ? (val) {
                                if (val)
                                  setDlgState(() => selectedStart = proposed);
                              }
                            : null,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Giờ đề nghị mới:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                '${_formatDateTime(reqStart.toIso8601String())} – ${_formatDateTime(propEnd.toIso8601String())}',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Thời lượng dịch vụ:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              '$durationMinutes phút (Không đổi)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Giá dịch vụ:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              'Giữ nguyên (Không phát sinh)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    decoration: InputDecoration(
                      labelText: 'Lý do xin làm sớm (tùy chọn)',
                      labelStyle: const TextStyle(fontSize: 12),
                      hintText: 'Ví dụ: Đã đến nơi sớm, sẵn sàng làm ngay',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                ),
                onPressed: validStart(selectedStart)
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: const Text('Gửi đề nghị cho Khách'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      final reqStart = selectedStart;
      if (!validStart(reqStart)) {
        reasonCtrl.dispose();
        return;
      }
      setState(() => _progressing = true);
      try {
        await widget.session.request(
          '/partner/jobs/${widget.id}/early-start-requests',
          method: 'POST',
          body: {
            'requestedStartAt': reqStart.toUtc().toIso8601String(),
            'reason': reasonCtrl.text.trim(),
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Đã gửi đề nghị bắt đầu sớm! Đang chờ khách hàng xác nhận.',
              ),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        await _load();
      } catch (e) {
        if (mounted) {
          final msg = e is ApiFailure ? e.message : e.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _error = msg);
        }
      } finally {
        if (mounted) setState(() => _progressing = false);
      }
    }
  }

  Future<void> _paymentAction(String path) async {
    if (_progressing) return;
    setState(() => _progressing = true);
    try {
      await widget.session.request(path, method: 'POST');
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _progressing = false);
    }
  }

  Timer? _timer;
  StreamSubscription<void>? _liveSubscription;

  @override
  void initState() {
    super.initState();
    _liveSubscription = widget.session.liveChanges.listen((_) {
      if (mounted) _load();
    });
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _load();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (_loading || _serviceUnavailable) return;
    _loading = true;
    try {
      final d = await widget.session.request(
        '/task-activity/${widget.id}${widget.preview ? '/preview' : (widget.partner ? '?partner=true' : '')}',
      );
      final loadedDetail = Map<String, dynamic>.from(d);
      if (!widget.preview) {
        loadedDetail['earlyStart'] = await widget.session.request(
          widget.partner
              ? '/partner/jobs/${widget.id}/start-eligibility'
              : '/customer/bookings/${widget.id}/start-eligibility',
        );
      }
      if (mounted) {
        setState(() {
          _detail = loadedDetail;
          _error = null;
        });
        if (widget.preview && !_viewRecorded) {
          await widget.session.request(
            '/task-activity/${widget.id}/view',
            method: 'POST',
          );
          _viewRecorded = true;
        }
      }
    } catch (e) {
      if (mounted &&
          widget.preview &&
          e is ApiFailure &&
          e.code == 'TASK_NOT_AVAILABLE') {
        setState(() {
          _serviceUnavailable = true;
          _detail = null;
          _error = null;
        });
        await showServiceUnavailable(context);
        if (mounted) Navigator.of(context).pop(false);
      } else if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Xác nhận hủy đơn?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn hủy đơn dịch vụ này không? Toàn bộ số tiền đã thanh toán sẽ được hoàn lại vào số dư của bạn.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Không hủy',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _paymentAction('/task-activity/${widget.id}/cancel');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _liveSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final task = detail?['task'];
    final addressDetails = detail?['addressDetails'] as Map? ?? {};
    final fullAddress = ['street', 'ward', 'district', 'city']
        .map((key) => addressDetails[key]?.toString().trim() ?? '')
        .where((part) => part.isNotEmpty)
        .toSet()
        .join(', ');
    final assigned = task?['taskerId'] != null;
    final closed = [
      'CANCELLED',
      'EXPIRED',
      'REFUNDED',
    ].contains(task?['status']);

    final earlyStart = (detail?['earlyStart'] as Map?) ?? {};
    final activeRequest = earlyStart['activeRequest'] as Map?;
    final canStart = earlyStart['canStart'] == true;
    final canTravel = earlyStart['canTravel'] == true;
    final canCheckIn = earlyStart['canCheckIn'] == true;
    final canRequestEarlyStart = earlyStart['canRequestEarlyStart'] == true;
    final earlyStartReasonCode = earlyStart['reasonCode']?.toString();
    final earlyStartMessage = earlyStart['message']?.toString();
    final earliestAllowedCheckin = earlyStart['earliestAllowedCheckin'];
    final approvedStartAt = task?['approvedStartAt'];
    final actualStartedAt = task?['actualStartedAt'];
    final checkedInAt = task?['checkedInAt'];
    final verifiedActualEndAt = task?['verifiedActualEndAt'];
    final originalScheduledStartAt = task?['originalScheduledStartAt'];
    final expectedEndAt = task?['expectedEndAt'];
    final durationMinutes = (task?['durationMinutes'] is num)
        ? (task!['durationMinutes'] as num).toInt()
        : 60;
    final scheduledDt = _parseDt(task?['scheduledAt']);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Hoạt động công việc',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        leading: widget.onBack == null
            ? null
            : IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
        actions: [
          if (assigned || widget.partner)
            IconButton(
              tooltip: widget.partner
                  ? 'Chat với khách hàng'
                  : 'Chat với Tasker',
              icon: Icon(
                Icons.chat_bubble_outline_rounded,
                color: widget.partner
                    ? const Color(0xFF1E5BF8)
                    : const Color(0xFF059669),
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TaskChatScreen(
                      session: widget.session,
                      taskId: widget.id,
                      partner: widget.partner,
                      initialTaskerName: task?['taskerName'],
                      initialCustomerName: task?['customerName'],
                      initialServiceName: task?['serviceName'],
                    ),
                  ),
                );
                if (mounted) _load();
              },
            ),
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      bottomNavigationBar: widget.preview && detail != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Nhận công việc này'),
                ),
              ),
            )
          : null,
      body: _serviceUnavailable
          ? const SizedBox.shrink()
          : detail == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 40,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                            ),
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.partner &&
                        [
                          'POSTED',
                          'MATCHING',
                          'TASKER_ON_THE_WAY',
                        ].contains(task['status']))
                      TaskArrivalReport(
                        session: widget.session,
                        taskId: widget.id,
                        scheduledAt: task['scheduledAt']?.toString(),
                        waitingForTasker: task['taskerId'] == null,
                      ),

                    // Customer: Card Phê duyệt / Từ chối đề nghị bắt đầu sớm từ Partner
                    if (!widget.partner &&
                        activeRequest != null &&
                        activeRequest['status'] == 'PENDING')
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFDE68A),
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0C0F172A),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.bolt_rounded,
                                    color: Color(0xFFD97706),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Partner đề nghị bắt đầu sớm',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: Color(0xFF92400E),
                                        ),
                                      ),
                                      Text(
                                        'Đối tác: ${task['taskerName'] ?? 'Đối tác tiếp nhận'}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFDE68A),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Giờ đã đặt:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      Text(
                                        _formatDateTime(
                                          originalScheduledStartAt ??
                                              task['scheduledAt'],
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Đề nghị làm lúc:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                      Text(
                                        '${_formatDateTime(activeRequest['requestedStartAt'])} – ${_formatDateTime(activeRequest['proposedEndAt'])}',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (activeRequest['reason'] != null &&
                                      activeRequest['reason']
                                          .toString()
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Lý do:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            activeRequest['reason'].toString(),
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const Divider(
                                    height: 14,
                                    color: Color(0xFFF1F5F9),
                                  ),
                                  Row(
                                    children: const [
                                      Icon(
                                        Icons.shield_outlined,
                                        size: 14,
                                        color: Color(0xFF059669),
                                      ),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Thời lượng và giá dịch vụ được bảo toàn nguyên vẹn.',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF059669),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (activeRequest['expiresAt'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Đề nghị có hiệu lực đến: ${_formatDateTime(activeRequest['expiresAt'])}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _progressing
                                        ? null
                                        : () => _customerDecision(
                                            activeRequest['id'].toString(),
                                            'REJECT',
                                          ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF475569),
                                      side: const BorderSide(
                                        color: Color(0xFFCBD5E1),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Giữ nguyên giờ đặt',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _progressing
                                        ? null
                                        : () => _customerDecision(
                                            activeRequest['id'].toString(),
                                            'APPROVE',
                                          ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Đồng ý bắt đầu sớm',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // Customer: Thông báo Partner đã đến nơi / Bắt đầu làm thực tế
                    if (!widget.partner &&
                        checkedInAt != null &&
                        task['status'] == 'ARRIVED')
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFF2563EB),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Đối tác đã đến nơi lúc ${_formatDateTime(checkedInAt)}. Đang chuẩn bị bắt đầu công việc.',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (!widget.partner && actualStartedAt != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.play_circle_filled_rounded,
                              color: Color(0xFF7C3AED),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bắt đầu thực tế lúc ${_formatDateTime(actualStartedAt)}.',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5B21B6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Partner: Khu vực 3 hành động độc lập (Check-in / Xin làm sớm / Bắt đầu việc)
                    if (widget.partner &&
                        !closed &&
                        task['status'] != 'COMPLETED')
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0C0F172A),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.work_history_rounded,
                                    color: Color(0xFF1E5BF8),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Điều phối & Bắt đầu ca làm',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Hành động di chuyển (nếu đang ACCEPTED)
                            if (task['status'] == 'ACCEPTED' && canTravel) ...[
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E5BF8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: (_progressing || !canTravel)
                                    ? null
                                    : () => _progress(
                                        'ACCEPTED',
                                        'TASKER_ON_THE_WAY',
                                      ),
                                icon: const Icon(
                                  Icons.directions_bike_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Bắt đầu di chuyển',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Hành động 1: Tôi đã đến (Check-in)
                            if (task['status'] == 'TASKER_ON_THE_WAY') ...[
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: canCheckIn
                                      ? const Color(0xFF0284C7)
                                      : const Color(0xFF94A3B8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: (_progressing || !canCheckIn)
                                    ? null
                                    : _checkIn,
                                icon: const Icon(
                                  Icons.location_on_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Đến nơi',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (!canCheckIn &&
                                  earliestAllowedCheckin != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Bạn có thể check-in từ ${_formatDateTime(earliestAllowedCheckin)} (trước giờ hẹn 15 phút).',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: 8),
                            ],

                            // Hành động 2: Xin bắt đầu sớm
                            if (task['status'] == 'ACCEPTED' && !canTravel) ...[
                              if (activeRequest != null &&
                                  activeRequest['status'] == 'PENDING') ...[
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.hourglass_top_rounded,
                                        size: 16,
                                        color: Color(0xFFD97706),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Đang chờ khách duyệt đề nghị làm lúc ${_formatDateTime(activeRequest['requestedStartAt'])}…',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFB45309),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ] else if (canRequestEarlyStart &&
                                  scheduledDt != null) ...[
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1E5BF8),
                                    side: const BorderSide(
                                      color: Color(0xFFBFDBFE),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _progressing
                                      ? null
                                      : () => _showEarlyStartDialog(
                                          scheduledDt,
                                          durationMinutes,
                                        ),
                                  icon: const Icon(
                                    Icons.bolt_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Gửi yêu cầu đến / làm sớm',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],

                            // Hành động 3: Bắt đầu công việc
                            if (task['status'] == 'ARRIVED' && canStart) ...[
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: canStart
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFCBD5E1),
                                  foregroundColor: canStart
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: (_progressing || !canStart)
                                    ? null
                                    : _startJob,
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Bắt đầu công việc',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (!canStart) ...[
                                const SizedBox(height: 6),
                                Text(
                                  earlyStartReasonCode ==
                                          'EARLY_START_REQUIRES_APPROVAL'
                                      ? 'Khách hẹn ${_formatDateTime(task['scheduledAt'])}. Cần khách hàng đồng ý trước khi bắt đầu sớm.'
                                      : (earlyStartMessage ??
                                            'Chưa đủ điều kiện bắt đầu.'),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFD97706),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],

                            if (task['status'] == 'ARRIVED' && !canStart)
                              Text(
                                'Đã check-in. Chờ đến ${_formatDateTime(earlyStart['allowedStartAt'] ?? task['scheduledAt'])} để bắt đầu công việc.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFD97706),
                                ),
                              ),

                            // Hành động 4: Hoàn thành công việc (nếu IN_PROGRESS)
                            if (task['status'] == 'IN_PROGRESS') ...[
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _progressing
                                    ? null
                                    : () =>
                                          _progress('IN_PROGRESS', 'COMPLETED'),
                                icon: const Icon(
                                  Icons.check_circle_rounded,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Hoàn thành công việc',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    // Service Overview Card
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  '#${task['id'].toString().substring(0, min(8, task['id'].toString().length)).toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              _buildStatusBadge(task['status'] ?? ''),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            task['serviceName'] ?? 'Dịch vụ',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Location & Schedule Card
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: Color(0xFFE11D48),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Địa chỉ thực hiện',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        fullAddress.isNotEmpty
                                            ? fullAddress
                                            : task['address'] ??
                                                  'Chưa cập nhật địa chỉ',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                          height: 1.35,
                                        ),
                                      ),
                                      for (final contact in {
                                        'recipientName': 'Người liên hệ',
                                        'recipientPhone':
                                            'Số điện thoại liên hệ',
                                      }.entries)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: SelectableText(
                                            '${contact.value}: ${(addressDetails[contact.key]?.toString() ?? '').trim().isEmpty ? 'Chưa có thông tin trong đơn' : addressDetails[contact.key]}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      for (final entry in {
                                        'label': 'Tên địa chỉ',
                                        'buildingType': 'Loại nhà',
                                        'buildingDescription': 'Vị trí cụ thể',
                                      }.entries)
                                        if ((addressDetails[entry.key]
                                                    ?.toString() ??
                                                '')
                                            .trim()
                                            .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              '${entry.value}: ${addressDetails[entry.key]}',
                                            ),
                                          ),
                                      if ((addressDetails['notes']
                                                  ?.toString() ??
                                              '')
                                          .trim()
                                          .isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Text(
                                            'Chỉ dẫn: ${addressDetails['notes']}',
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (task['scheduledAt'] != null) ...[
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_month_rounded,
                                      color: Color(0xFF0284C7),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Thời gian hẹn làm việc',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDateTime(
                                            originalScheduledStartAt ??
                                                task['scheduledAt'],
                                          ),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0284C7),
                                          ),
                                        ),
                                        if (approvedStartAt != null) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFFA7F3D0),
                                              ),
                                            ),
                                            child: Text(
                                              'Duyệt làm sớm: ${_formatDateTime(approvedStartAt)}${expectedEndAt != null ? ' → Dự kiến xong: ${_formatDateTime(expectedEndAt)}' : ''}',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF047857),
                                              ),
                                            ),
                                          ),
                                        ],
                                        // Independent operational timestamps
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            if (task['acceptedAt'] != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF1F5F9,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Nhận đơn: ${_formatDateTime(task['acceptedAt'])}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                            if (checkedInAt != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFEFF6FF,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFBFDBFE,
                                                    ),
                                                  ),
                                                ),
                                                child: Text(
                                                  'Đã đến: ${_formatDateTime(checkedInAt)}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF1D4ED8),
                                                  ),
                                                ),
                                              ),
                                            if (actualStartedAt != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF5F3FF,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFDDD6FE,
                                                    ),
                                                  ),
                                                ),
                                                child: Text(
                                                  'Bắt đầu thật: ${_formatDateTime(actualStartedAt)}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF6D28D9),
                                                  ),
                                                ),
                                              ),
                                            if (verifiedActualEndAt != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFEFCE8,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFFEF08A,
                                                    ),
                                                  ),
                                                ),
                                                child: Text(
                                                  'Nghiệm thu: ${_formatDateTime(verifiedActualEndAt)}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFFA16207),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (detail['booking'] is Map &&
                        (detail['booking'] as Map).isNotEmpty)
                      TaskBookingServicesCard(
                        booking: detail['booking'] as Map,
                        partner: widget.partner,
                        partnerNetAmount: task['partnerNetAmount'] as num?,
                      ),
                    // Payment & Cancellation Policy Card
                    if ((detail['payment'] as Map?)?.isNotEmpty == true)
                      Builder(
                        builder: (context) {
                          final payment = detail['payment'] as Map;
                          final isCash = payment['method'] == 'CASH';
                          final pStatus = payment['status'];
                          final matchDeadlineDt = _parseDt(
                            payment['match_deadline'],
                          );
                          final canCancelNow =
                              !assigned &&
                              ['POSTED', 'MATCHING'].contains(task['status']);

                          String paymentSummary() {
                            if (isCash) {
                              if (pStatus == 'PAID') {
                                return 'Đối tác đã xác nhận nhận thanh toán trực tiếp.';
                              }
                              return 'Thanh toán trực tiếp — chờ Đối tác xác nhận thu tiền.';
                            }
                            if (pStatus == 'REFUNDED') {
                              return 'Đã hoàn tiền vào số dư của bạn.';
                            }
                            return 'Đã thanh toán ngân hàng giả lập.';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isCash
                                            ? const Color(0xFFFEF3C7)
                                            : const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isCash
                                            ? Icons.payments_outlined
                                            : Icons.account_balance_rounded,
                                        color: isCash
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFF059669),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isCash
                                                ? 'Tiền mặt trực tiếp'
                                                : 'Chuyển khoản / Ngân hàng',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          if (((payment['balance_amount']
                                                      as num?) ??
                                                  0) >
                                              0) ...[
                                            Text(
                                              'Đã dùng số dư: ${payment['balance_amount']} đ',
                                            ),
                                            Text(
                                              'Phần ${isCash ? 'tiền mặt' : 'ngân hàng'}: ${((payment['amount'] as num?) ?? 0) - ((payment['balance_amount'] as num?) ?? 0)} đ',
                                            ),
                                          ],
                                          Text(
                                            paymentSummary(),
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: pStatus == 'PAID'
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFF64748B),
                                              fontWeight: pStatus == 'PAID'
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Customer Cancellation Policy Box
                                if (!widget.partner &&
                                    [
                                      'POSTED',
                                      'MATCHING',
                                      'ACCEPTED',
                                      'TASKER_ON_THE_WAY',
                                      'ARRIVED',
                                    ].contains(task['status'])) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: canCancelNow
                                          ? const Color(0xFFF8FAFC)
                                          : const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: canCancelNow
                                            ? const Color(0xFFE2E8F0)
                                            : const Color(0xFFFDE68A),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              canCancelNow
                                                  ? Icons.info_outline_rounded
                                                  : Icons.timer_outlined,
                                              size: 16,
                                              color: canCancelNow
                                                  ? const Color(0xFF475569)
                                                  : const Color(0xFFD97706),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              canCancelNow
                                                  ? 'Chính sách hủy đơn & Hoàn tiền'
                                                  : 'Tasker đã nhận việc',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.5,
                                                color: canCancelNow
                                                    ? const Color(0xFF1E293B)
                                                    : const Color(0xFF92400E),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          '• Có thể hủy ngay khi chưa có Tasker nhận việc.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF334155),
                                            height: 1.4,
                                          ),
                                        ),
                                        if (matchDeadlineDt != null &&
                                            !assigned &&
                                            !closed) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '• Tự hủy nếu chưa có người nhận đến ${_formatDateTime(matchDeadlineDt)}.',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: canCancelNow
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF94A3B8),
                                      side: BorderSide(
                                        color: canCancelNow
                                            ? const Color(0xFFFECACA)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _progressing || !canCancelNow
                                        ? null
                                        : () => _confirmCancel(context),
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      canCancelNow
                                          ? (isCash
                                                ? 'Hủy đơn'
                                                : 'Hủy đơn và hoàn tiền đã thanh toán')
                                          : assigned
                                          ? 'Tasker đã nhận việc — không thể hủy'
                                          : closed
                                          ? 'Đơn đã kết thúc'
                                          : 'Tasker đã nhận việc — không thể hủy',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ],

                                // Partner Cash Confirmation Button
                                if (widget.partner &&
                                    task['status'] == 'COMPLETED' &&
                                    isCash &&
                                    pStatus == 'AWAITING_CASH') ...[
                                  const SizedBox(height: 14),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 13,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _progressing
                                        ? null
                                        : () => _paymentAction(
                                            '/partner/jobs/${widget.id}/cash-received',
                                          ),
                                    icon: const Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Xác nhận đã nhận tiền trực tiếp',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),

                    // Work Progress Timeline Card
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.timeline_rounded,
                                color: Color(0xFF059669),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tiến trình công việc',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if ((detail['events'] as List).isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Chưa có dữ liệu tiến trình.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            )
                          else
                            for (
                              int i = 0;
                              i < (detail['events'] as List).length;
                              i++
                            )
                              Builder(
                                builder: (context) {
                                  final events = detail['events'] as List;
                                  final event = events[i];
                                  final isLast = i == events.length - 1;

                                  return IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Column(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFECFDF5),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF059669,
                                                  ),
                                                  width: 2,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.check_rounded,
                                                size: 14,
                                                color: Color(0xFF059669),
                                              ),
                                            ),
                                            if (!isLast)
                                              Expanded(
                                                child: Container(
                                                  width: 2,
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                      ),
                                                  color: const Color(
                                                    0xFFA7F3D0,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              bottom: isLast ? 4 : 18,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .baseline,
                                                  textBaseline:
                                                      TextBaseline.alphabetic,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        activityStatus(
                                                          event['status'],
                                                        ),
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Color(
                                                            0xFF0F172A,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      _formatTimelineTime(
                                                        event['at'],
                                                      ),
                                                      style: const TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Color(
                                                          0xFF64748B,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (event['reason'] != null &&
                                                    event['reason']
                                                        .toString()
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    event['reason'].toString(),
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      color: Color(0xFF475569),
                                                      height: 1.35,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                        ],
                      ),
                    ),

                    // Tasker & Live Chat Section
                    if (closed)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.event_busy_outlined,
                              color: Color(0xFF64748B),
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              task['status'] == 'EXPIRED'
                                  ? 'Đơn đã hết hạn'
                                  : 'Đơn đã hủy',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Đã dừng tìm Tasker cho đơn này.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    else if (!assigned)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFA7F3D0),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.person_search_rounded,
                                color: Color(0xFF059669),
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Hệ thống đang kết nối Tasker',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Chat sẽ xuất hiện khi công việc đã có Tasker.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.radar_rounded,
                                    size: 14,
                                    color: Color(0xFF059669),
                                  ),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Đang tìm Tasker đủ tiêu chuẩn gần bạn...',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF475569),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      // Assigned Tasker Profile
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: widget.partner
                                  ? const Color(0xFFEFF6FF)
                                  : const Color(0xFFECFDF5),
                              child: Text(
                                (widget.partner
                                        ? (task['customerName'] ?? 'K')
                                        : (task['taskerName'] ?? 'T'))[0]
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: widget.partner
                                      ? const Color(0xFF1E5BF8)
                                      : const Color(0xFF059669),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        widget.partner
                                            ? (task['customerName'] ??
                                                  'Khách hàng')
                                            : (task['taskerName'] ??
                                                  'Tasker Đối tác'),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.verified_rounded,
                                        size: 16,
                                        color: widget.partner
                                            ? const Color(0xFF1E5BF8)
                                            : const Color(0xFF059669),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.partner
                                        ? 'Khách hàng đặt dịch vụ trên TaskLy'
                                        : 'Đối tác TaskLy đã xác thực hồ sơ',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Dedicated Chat Section Card
                      InkWell(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TaskChatScreen(
                                session: widget.session,
                                taskId: widget.id,
                                partner: widget.partner,
                                initialTaskerName: task['taskerName'],
                                initialCustomerName: task['customerName'],
                                initialServiceName: task['serviceName'],
                              ),
                            ),
                          );
                          if (mounted) _load();
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: widget.partner
                                          ? const Color(0xFFEFF6FF)
                                          : const Color(0xFFECFDF5),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: widget.partner
                                            ? const Color(0xFFBFDBFE)
                                            : const Color(0xFFA7F3D0),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.chat_bubble_rounded,
                                      color: widget.partner
                                          ? const Color(0xFF1E5BF8)
                                          : const Color(0xFF059669),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.partner
                                              ? 'Chat với ${task['customerName'] ?? 'khách hàng'}'
                                              : 'Chat với ${task['taskerName'] ?? 'Tasker'}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Phòng chat riêng • Gửi hình ảnh trực tiếp',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 15,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFF1F5F9),
                                  ),
                                ),
                                child: (detail['messages'] as List).isEmpty
                                    ? Text(
                                        widget.partner
                                            ? 'Chưa có tin nhắn. Gửi lời chào cho khách hàng.'
                                            : 'Chưa có tin nhắn. Gửi lời chào cho Tasker của bạn.',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                        ),
                                      )
                                    : Row(
                                        children: [
                                          Icon(
                                            Icons.chat_outlined,
                                            size: 16,
                                            color: widget.partner
                                                ? const Color(0xFF1E5BF8)
                                                : const Color(0xFF059669),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${(detail['messages'] as List).length} tin nhắn • Gần nhất: ${((detail['messages'] as List).last['text'] ?? '').toString()}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF334155),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: widget.partner
                                        ? const Color(0xFF1E5BF8)
                                        : const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => TaskChatScreen(
                                          session: widget.session,
                                          taskId: widget.id,
                                          partner: widget.partner,
                                          initialTaskerName: task['taskerName'],
                                          initialCustomerName:
                                              task['customerName'],
                                          initialServiceName:
                                              task['serviceName'],
                                        ),
                                      ),
                                    );
                                    if (mounted) _load();
                                  },
                                  icon: const Icon(
                                    Icons.chat_bubble_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Mở cuộc trò chuyện',
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
                      ),
                    ],

                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class TaskBookingServicesCard extends StatefulWidget {
  const TaskBookingServicesCard({
    super.key,
    required this.booking,
    this.partner = false,
    this.partnerNetAmount,
  });

  final Map booking;
  final bool partner;
  final num? partnerNetAmount;

  @override
  State<TaskBookingServicesCard> createState() =>
      _TaskBookingServicesCardState();
}

class _TaskBookingServicesCardState extends State<TaskBookingServicesCard> {
  final ScrollController _chipsScrollController = ScrollController();
  final Set<int> _expandedServices = {};
  final List<GlobalKey> _serviceKeys = [];
  int _activeServiceIndex = 0;
  int? _highlightedIndex;

  @override
  void initState() {
    super.initState();
    final services = widget.booking['services'] as List? ?? [];
    for (int i = 0; i < services.length; i++) {
      _expandedServices.add(i);
      _serviceKeys.add(GlobalKey());
    }
  }

  @override
  void didUpdateWidget(covariant TaskBookingServicesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final services = widget.booking['services'] as List? ?? [];
    if (_serviceKeys.length != services.length) {
      _serviceKeys.clear();
      for (int i = 0; i < services.length; i++) {
        _serviceKeys.add(GlobalKey());
      }
    }
  }

  Timer? _highlightTimer;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _chipsScrollController.dispose();
    super.dispose();
  }

  void _scrollToService(int index) {
    final services = widget.booking['services'] as List? ?? [];
    if (index < 0 || index >= services.length) return;

    setState(() {
      _activeServiceIndex = index;
      _highlightedIndex = index;
      _expandedServices.add(index);
    });

    if (_chipsScrollController.hasClients) {
      const chipWidth = 150.0;
      final targetOffset = max(0.0, (index * chipWidth) - 60.0);
      _chipsScrollController.animateTo(
        min(targetOffset, _chipsScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index < _serviceKeys.length) {
        final ctx = _serviceKeys[index].currentContext;
        if (ctx != null && mounted) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            alignment: 0.08,
          );
        }
      }
    });

    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _highlightedIndex == index) {
        setState(() => _highlightedIndex = null);
      }
    });
  }

  void _toggleService(int index) {
    setState(() {
      if (_expandedServices.contains(index)) {
        _expandedServices.remove(index);
      } else {
        _expandedServices.add(index);
        _activeServiceIndex = index;
      }
    });

    if (_expandedServices.contains(index)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (index < _serviceKeys.length) {
          final ctx = _serviceKeys[index].currentContext;
          if (ctx != null && mounted) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              alignment: 0.08,
            );
          }
        }
      });
    }
  }

  static String _formatText(dynamic value) {
    if (value is List) return value.join(', ');
    if (value == true) return 'Có';
    if (value == false) return 'Không';
    return '${value ?? ''}';
  }

  static IconData _resolveServiceIcon(String name) {
    final s = name.toLowerCase();
    if (s.contains('lạnh') || s.contains('điều hòa') || s.contains('ac')) {
      return Icons.ac_unit_rounded;
    }
    if (s.contains('vệ sinh') ||
        s.contains('dọn') ||
        s.contains('giặt') ||
        s.contains('sạch')) {
      return Icons.cleaning_services_rounded;
    }
    if (s.contains('điện') || s.contains('đèn')) {
      return Icons.electric_bolt_rounded;
    }
    if (s.contains('nước') || s.contains('ống') || s.contains('rò')) {
      return Icons.plumbing_rounded;
    }
    if (s.contains('khóa') || s.contains('cửa')) {
      return Icons.lock_open_rounded;
    }
    if (s.contains('sơn') || s.contains('nhà')) {
      return Icons.format_paint_rounded;
    }
    if (s.contains('bếp') || s.contains('nấu')) {
      return Icons.soup_kitchen_rounded;
    }
    if (s.contains('xe') || s.contains('rửa')) {
      return Icons.directions_car_rounded;
    }
    return Icons.home_repair_service_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.booking['services'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF059669),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Chi tiết dịch vụ',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (services.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    '${services.length} dịch vụ',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              if (widget.booking['duration'] != null &&
                  (widget.booking['duration'] as num) > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.booking['duration']} giờ',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Multiple services horizontal quick-nav chips (Bấm sẽ scroll)
          if (services.length > 1) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 14,
                        color: Color(0xFF0284C7),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Chạm dịch vụ để cuộn nhanh đến:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    controller: _chipsScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: List.generate(services.length, (idx) {
                        final s = services[idx] as Map;
                        final isSelected = _activeServiceIndex == idx;
                        final sName = _formatText(s['serviceName']);
                        final sTotal = _formatCurrency(_serviceAmount(s, idx));

                        return Padding(
                          padding: EdgeInsets.only(
                            right: idx == services.length - 1 ? 0 : 8,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _scrollToService(idx),
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF059669)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFCBD5E1),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF059669)
                                                .withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFFE2E8F0),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${idx + 1}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isSelected
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 150,
                                      ),
                                      child: Text(
                                        sName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      sTotal,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? const Color(0xFFA7F3D0)
                                            : const Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Service Card List
          const SizedBox(height: 10),
          for (int idx = 0; idx < services.length; idx++)
            _buildServiceItem(services[idx] as Map, idx, services.length),

          // General Booking Description / Notes
          if (services.isEmpty &&
              _formatText(widget.booking['description']).trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Yêu cầu: ${_formatText(widget.booking['description'])}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_formatText(widget.booking['notes']).trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.note_alt_outlined,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lưu ý cho Đối tác / Partner: ${_formatText(widget.booking['notes'])}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF78350F),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Grand Total Bill Summary Card
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                if (!widget.partner) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng giá dịch vụ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        _formatCurrency(widget.booking['subtotal'] ?? 0),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  if ((widget.booking['platformFee'] ?? 0) > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Phí dịch vụ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          _formatCurrency(widget.booking['platformFee'] ?? 0),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.partner ? 'Tiền thực nhận' : 'Tổng thanh toán',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      _formatCurrency(
                        widget.partner
                            ? (widget.partnerNetAmount ?? 0)
                            : (widget.booking['total'] ?? 0),
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  num _serviceAmount(Map service, int index) {
    final gross = (service['total'] ?? service['subtotal'] ?? 0) as num;
    if (!widget.partner) return gross;
    final services = (widget.booking['services'] as List? ?? []);
    final amounts = services
        .map((s) => (s['total'] ?? s['subtotal'] ?? 0) as num)
        .toList();
    final total = amounts.fold<num>(0, (a, b) => a + b);
    if (total <= 0 || widget.partnerNetAmount == null) return 0;
    final before = amounts.take(index).fold<num>(0, (a, b) => a + b);
    return ((before + gross) * widget.partnerNetAmount! / total).round() -
        (before * widget.partnerNetAmount! / total).round();
  }

  Widget _buildServiceItem(Map s, int idx, int totalCount) {
    final isExpanded = _expandedServices.contains(idx);
    final isHighlighted = _highlightedIndex == idx;
    final sName = _formatText(s['serviceName']);
    final mode = s['mode'];
    final quantity = s['quantity'];
    final quantityLabel = s['quantityLabel'] ?? 'Số lượng';
    final fields = s['fields'] as List? ?? [];
    final desc = _formatText(s['description']).trim();
    final subtotal = _formatCurrency(_serviceAmount(s, idx));

    String subtitleText = '';
    if (mode != 'FIXED' && quantity != null) {
      subtitleText = '$quantityLabel: $quantity';
    } else if (mode == 'FIXED') {
      subtitleText = 'Trọn gói';
    }

    return AnimatedContainer(
      key: _serviceKeys.length > idx ? _serviceKeys[idx] : null,
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF059669)
              : (isExpanded
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFFE2E8F0)),
          width: isHighlighted ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? const Color(0xFF059669).withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: isHighlighted ? 12 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (Tappable: Tap to expand & scroll)
            Material(
              color: isHighlighted
                  ? const Color(0xFFECFDF5)
                  : (isExpanded ? const Color(0xFFF8FAFC) : Colors.white),
              child: InkWell(
                onTap: () => _toggleService(idx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Icon(
                          _resolveServiceIcon(sName),
                          color: const Color(0xFF059669),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#${idx + 1}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    sName,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (subtitleText.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitleText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              subtotal,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: const Color(0xFF94A3B8),
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Expanded Content
            if (isExpanded) ...[
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Rate Breakdown (if not fixed)
                    if (mode != 'FIXED') ...[
                      if (s['unitAmount'] != null)
                        _buildSpecRow(
                          'Đơn giá',
                          '${_formatCurrency(s['unitAmount'])} / $quantityLabel',
                          isFirst: true,
                        ),
                      if ((s['baseAmount'] ?? 0) > 0)
                        _buildSpecRow(
                          'Giá cơ bản',
                          _formatCurrency(s['baseAmount']),
                        ),
                    ] else if ((s['baseAmount'] ?? 0) > 0) ...[
                      _buildSpecRow(
                        'Giá trọn gói',
                        _formatCurrency(s['baseAmount']),
                        isFirst: true,
                      ),
                    ],

                    // Field Specifications Table
                    if (fields.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Thông số & Hạng mục chi tiết',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          children: [
                            for (int fIdx = 0; fIdx < fields.length; fIdx++)
                              _buildFieldRow(fields[fIdx] as Map, fIdx),
                          ],
                        ),
                      ),
                    ],

                    // Description / Custom requirement box
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF78350F),
                                    height: 1.35,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: 'Yêu cầu: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(text: desc),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Subtotal Footer Bar + Quick-jump to next/prev service!
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0FDF4),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    if (totalCount > 1) ...[
                      if (idx < totalCount - 1)
                        InkWell(
                          onTap: () => _scrollToService(idx + 1),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            child: Row(
                              children: const [
                                Text(
                                  'Dịch vụ tiếp theo',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                                SizedBox(width: 3),
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  size: 14,
                                  color: Color(0xFF0284C7),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        InkWell(
                          onTap: () => _scrollToService(0),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            child: Row(
                              children: const [
                                Text(
                                  'Về dịch vụ đầu',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                SizedBox(width: 3),
                                Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                    const Spacer(),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: widget.partner
                                ? 'Thực nhận: '
                                : 'Thành tiền: ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          TextSpan(
                            text: subtotal,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, {bool isFirst = false}) {
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(Map field, int fIdx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fIdx.isEven ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF94A3B8),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatText(field['label']),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              _formatText(field['value']),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
