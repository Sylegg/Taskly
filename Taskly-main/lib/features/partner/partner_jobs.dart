import 'dart:async';

import 'partner_bank.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/api.dart';
import '../task_activity.dart';
import '../task_chat.dart';
import '../service_unavailable.dart';
import 'partner_portrait.dart';
import 'partner_work_areas.dart';

class PartnerJobs extends StatefulWidget {
  const PartnerJobs({super.key, required this.session, this.application});

  final Session session;
  final Map<String, dynamic>? application;

  @override
  State<PartnerJobs> createState() => _PartnerJobsState();
}

class _PartnerJobsState extends State<PartnerJobs> {
  List<dynamic> jobs = [];
  List<String> openCities = [], closedCities = [];
  bool workAreasLoaded = false;
  List<dynamic> myActivities = [];
  bool loading = true;
  bool loadingActivities = false;
  String? accepting, error;
  int revision = 0;

  // Partner Workspace state
  bool isOnline = true;
  int selectedTab = 0; // 0: Việc mới, 1: Đang làm, 2: Đã xong
  String? progressingTaskId;
  List<dynamic> mySchedule = [];
  num? serviceIncome;

  StreamSubscription<void>? _liveSubscription;
  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _liveSubscription = widget.session.liveChanges.listen((_) {
      if (mounted) load(background: true);
    });
    load();
  }

  bool _fetching = false;
  Future<void> load({bool background = false}) async {
    if (!mounted || _fetching) return;
    _fetching = true;
    if (!background) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final results = await Future.wait([
        widget.session.request('/partner/jobs'),
        widget.session
            .request('/task-activity?partner=true')
            .catchError((_) => []),
        widget.session
            .request('/partner/work-areas')
            .catchError((_) => {'areaIds': [], 'areas': []}),
        widget.session
            .request('/partner/my-schedule')
            .catchError((_) => []),
        widget.session.request('/partner/wallet'),
      ]);
      if (mounted) {
        setState(() {
          final workAreas = (results[2] is Map)
              ? (results[2] as Map)
              : {'areaIds': [], 'areas': []};
          final chosenIds = Set<String>.from(workAreas['areaIds'] ?? const []);
          final chosen = ((workAreas['areas'] as List?) ?? const []).cast<Map>().where(
            (a) => chosenIds.contains(a['id'].toString()),
          );
          openCities = chosen
              .where((a) => a['recruiting'] == true)
              .map((a) => a['city'].toString())
              .toList();
          closedCities = chosen
              .where((a) => a['recruiting'] != true)
              .map((a) => a['city'].toString())
              .toList();
          workAreasLoaded = true;
          error = null;
          jobs = results[0] as List;
          myActivities = (results[1] is List) ? (results[1] as List) : [];
          mySchedule = (results[3] is List) ? (results[3] as List) : [];
          serviceIncome = (results[4] as Map)['serviceIncome'] as num?;
          revision++;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      _fetching = false;
      if (mounted) setState(() => loading = false);
    }
  }

  List<dynamic> get _activeTasks => myActivities.where((t) {
    final st = t['status']?.toString() ?? '';
    return [
      'ACCEPTED',
      'TASKER_ON_THE_WAY',
      'ARRIVED',
      'IN_PROGRESS',
    ].contains(st);
  }).toList();

  List<dynamic> get _completedTasks => myActivities.where((t) {
    final st = t['status']?.toString() ?? '';
    return ['COMPLETED', 'PAID'].contains(st);
  }).toList();

  num get _todayEarnings => _completedTasks.fold<num>(0, (sum, t) {
    final amt = t['partnerNetAmount'] ?? t['partner_net_amount'] ?? 0;
    return sum + (amt is num ? amt : (num.tryParse(amt.toString()) ?? 0));
  });

  Future<void> previewJob(String id) async {
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskActivityDetail(
          session: widget.session,
          id: id,
          partner: true,
          preview: true,
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await accept(id);
    } else if (mounted) {
      await load();
    }
  }

  Future<void> accept(String id) async {
    setState(() {
      accepting = id;
      error = null;
    });
    try {
      final bank = await widget.session
          .request('/partner/bank-account')
          .catchError((_) => {'accountNumber': 'default'});
      if (!mounted) return;
      if (bank == null) {
        final add = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Thêm ngân hàng để nhận việc'),
            content: const Text(
              'Bạn cần thêm tài khoản ngân hàng trước khi nhận công việc này.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Thêm ngân hàng'),
              ),
            ],
          ),
        );
        if (add == true && mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PartnerBank(session: widget.session),
            ),
          );
        }
        return;
      }
      final wallet = await widget.session.request('/partner/wallet');
      if (!mounted) return;
      if (((wallet['balance'] as num?)?.toInt() ?? 0) <= 200000) {
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Chưa đủ số dư nhận đơn'),
          content: const Text('Số dư khả dụng ví Partner phải trên 200.000đ mới được nhận đơn. Vui lòng nạp thêm tiền vào ví.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu'))],
        ));
        return;
      }
      await widget.session.request('/partner/jobs/$id/accept', method: 'POST');
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TaskActivityDetail(
            session: widget.session,
            id: id,
            partner: true,
          ),
        ),
      );
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        if (e is ApiFailure && e.code == 'TASK_NOT_AVAILABLE') {
          await showServiceUnavailable(context);
          if (mounted) await load();
          return;
        }
        final msg = e is ApiFailure
            ? e.message
            : e.toString().replaceFirst('Exception: ', '');
        final isConflict = (e is ApiFailure &&
                (e.status == 409 ||
                    e.code == 'BUFFER_TOO_SHORT' ||
                    e.code == 'SCHEDULE_CONFLICT' ||
                    e.code == 'JOB_ALREADY_ASSIGNED')) ||
            msg.contains('trùng') ||
            msg.contains('buffer') ||
            msg.contains('tiếp nhận') ||
            msg.contains('60 phút');
        if (isConflict) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.event_busy_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Không thể nhận việc',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF2563EB),
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Quy định: Hai công việc liền nhau cần cách nhau ít nhất 60 phút để đảm bảo di chuyển an toàn.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Xem việc khác',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
          if (mounted) await load();
        } else {
          setState(() => error = msg);
        }
      }
    } finally {
      if (mounted) setState(() => accepting = null);
    }
  }

  Future<void> _progressJob(
    String taskId,
    String currentStatus,
    String nextStatus,
  ) async {
    setState(() => progressingTaskId = taskId);
    try {
      if (nextStatus == 'ARRIVED' || nextStatus == 'COMPLETED') {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TaskChatScreen(session: widget.session,
              taskId: taskId, partner: true, checkInMode: nextStatus == 'ARRIVED', completionMode: nextStatus == 'COMPLETED'),
        ));
      } else if (nextStatus == 'IN_PROGRESS') {
        await widget.session.request(
          '/partner/jobs/$taskId/start',
          method: 'POST',
        );
      } else {
        await widget.session.request(
          '/partner/jobs/$taskId/status',
          method: 'POST',
          body: {
            'expectedStatus': currentStatus,
            'status': nextStatus,
            'requestId':
                'job-$taskId-$nextStatus-${DateTime.now().millisecondsSinceEpoch}',
          },
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã cập nhật trạng thái: ${_jobStatusName(nextStatus)}',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await load();
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiFailure ? e.message : e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => progressingTaskId = null);
    }
  }

  String _formatVnd(dynamic amount) {
    if (amount == null) return '0 đ';
    final num val = amount is num
        ? amount
        : (num.tryParse(amount.toString()) ?? 0);
    final str = val.toInt().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return '${buffer.toString()} đ';
  }

  String _formatScheduledTime(dynamic scheduledAt) {
    if (scheduledAt == null) return 'Thời gian linh hoạt';
    try {
      final dt = DateTime.parse(scheduledAt.toString()).toLocal();
      final now = DateTime.now();
      final isToday =
          dt.year == now.year && dt.month == now.month && dt.day == now.day;
      final isTomorrow =
          dt.year == now.year && dt.month == now.month && dt.day == now.day + 1;
      final timeStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (isToday) return '$timeStr · Hôm nay';
      if (isTomorrow) return '$timeStr · Ngày mai';
      return '$timeStr · ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return scheduledAt.toString();
    }
  }

  String _formatFullScheduledTime(dynamic scheduledAt) {
    if (scheduledAt == null) return 'Thời gian linh hoạt';
    try {
      final dt = DateTime.parse(scheduledAt.toString()).toLocal();
      final timeStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      final dateStr =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      return '$timeStr · $dateStr';
    } catch (_) {
      return scheduledAt.toString();
    }
  }

  String _formatDuration(dynamic durationMinutes) {
    final mins = (durationMinutes is num)
        ? durationMinutes.toInt()
        : (int.tryParse(durationMinutes?.toString() ?? '') ?? 60);
    if (mins >= 60 && mins % 60 == 0) {
      return '$mins phút (${mins ~/ 60} giờ)';
    } else if (mins > 60) {
      return '$mins phút (${mins ~/ 60}g ${mins % 60}p)';
    }
    return '$mins phút';
  }

  IconData _resolveServiceIcon(String name) {
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
    return Icons.handyman_rounded;
  }

  String _jobStatusName(String status) => switch (status) {
    'POSTED' || 'MATCHING' => 'Đang tìm Tasker',
    'ACCEPTED' => 'Đã nhận việc',
    'TASKER_ON_THE_WAY' => 'Đang di chuyển',
    'ARRIVED' => 'Đã đến nơi',
    'IN_PROGRESS' => 'Đang thực hiện',
    'COMPLETED' => 'Đã hoàn thành',
    'PAID' => 'Đã thanh toán',
    'CANCELLED' => 'Đã hủy',
    _ => status,
  };

  (String nextStatus, String actionLabel, IconData icon)? _nextActionForStatus(
    String current,
  ) => switch (current) {
    'ACCEPTED' => (
      'TASKER_ON_THE_WAY',
      'Bắt đầu di chuyển',
      Icons.directions_bike_rounded,
    ),
    'TASKER_ON_THE_WAY' => ('ARRIVED', 'Đã đến nơi', Icons.location_on_rounded),
    'ARRIVED' => ('IN_PROGRESS', 'Bắt đầu làm việc', Icons.play_arrow_rounded),
    'IN_PROGRESS' => (
      'COMPLETED',
      'Hoàn thành việc',
      Icons.check_circle_rounded,
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final partnerName = widget.application?['fullName']?.toString().trim();
    final displayName = (partnerName != null && partnerName.isNotEmpty)
        ? partnerName
        : 'Đối tác TaskLy';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // =====================================================================
        // 1. HERO WORKSPACE & STATUS BAR
        // =====================================================================
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x280F172A),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Partner identity & Online/Offline switch
              Row(
                children: [
                  PartnerPortrait(
                    session: widget.session,
                    fallback: CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF10B981),
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'T',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x2E10B981),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0x6610B981),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF34D399),
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'ĐỐI TÁC CHÍNH THỨC',
                                  style: TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ONLINE / OFFLINE TOGGLE BUTTON
                  _PartnerStatusToggleSwitch(
                    isOnline: isOnline,
                    onToggle: () async {
                      if (isOnline) {
                        try {
                          final activities = await widget.session.request('/task-activity?partner=true') as List;
                          if (!mounted) return;
                          if (activities.any((task) => ['TASKER_ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS'].contains(task['status']))) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Bạn đang thực hiện đơn dịch vụ. Hãy hoàn thành đơn trước khi tắt trực tuyến.'),
                            ));
                            return;
                          }
                        } catch (_) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Chưa kiểm tra được đơn đang làm. Vui lòng thử lại sau.'),
                          ));
                          return;
                        }
                      }
                      if (!mounted) return;
                      final nextState = !isOnline;
                      setState(() => isOnline = nextState);
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                nextState
                                    ? Icons.check_circle_rounded
                                    : Icons.bedtime_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  nextState
                                      ? 'Bạn đã bật TRỰC TUYẾN - Sẵn sàng nhận việc!'
                                      : 'Đã chuyển sang chế độ TẠM NGHỈ.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: nextState
                              ? const Color(0xFF059669)
                              : const Color(0xFF334155),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: Color(0x24FFFFFF), height: 1),
              const SizedBox(height: 14),

              // PERFORMANCE METRICS BAR
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: const Color(0xFF34D399),
                      title: 'Thu nhập dịch vụ',
                      value: serviceIncome == null ? 'Đang cập nhật' : _formatVnd(serviceIncome!),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: const Color(0x24FFFFFF),
                  ),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.hourglass_top_rounded,
                      iconColor: const Color(0xFFFBBF24),
                      title: 'Đang làm',
                      value: '${_activeTasks.length} việc',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: const Color(0x24FFFFFF),
                  ),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.check_circle_rounded,
                      iconColor: const Color(0xFF60A5FA),
                      title: 'Đã xong',
                      value: '${_completedTasks.length} việc',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // =====================================================================
        // 2. SEGMENTED TABS (Việc mới / Đang làm / Đã xong)
        // =====================================================================
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildTabItem(
                  index: 0,
                  label: 'Việc mới',
                  icon: Icons.bolt_rounded,
                  badgeCount: jobs.length,
                  activeColor: const Color(0xFF2563EB),
                ),
              ),
              Expanded(
                child: _buildTabItem(
                  index: 1,
                  label: 'Đang làm',
                  icon: Icons.pending_actions_rounded,
                  badgeCount: _activeTasks.length,
                  activeColor: const Color(0xFFD97706),
                ),
              ),
              Expanded(
                child: _buildTabItem(
                  index: 2,
                  label: 'Đã xong',
                  icon: Icons.task_alt_rounded,
                  badgeCount: _completedTasks.length,
                  activeColor: const Color(0xFF059669),
                ),
              ),
            ],
          ),
        ),

        // HEADER ROW WITH TITLE & ACTION BUTTONS
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: selectedTab == 0
                                ? const Color(0xFFEFF6FF)
                                : selectedTab == 1
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            selectedTab == 0
                                ? Icons.explore_rounded
                                : selectedTab == 1
                                ? Icons.hourglass_top_rounded
                                : Icons.history_rounded,
                            size: 15,
                            color: selectedTab == 0
                                ? const Color(0xFF2563EB)
                                : selectedTab == 1
                                ? const Color(0xFFD97706)
                                : const Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            selectedTab == 0
                                ? 'Công việc phù hợp'
                                : selectedTab == 1
                                ? 'Công việc đang thực hiện'
                                : 'Lịch sử công việc',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selectedTab == 0 && jobs.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Text(
                              '${jobs.length}',
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selectedTab == 0
                          ? 'Theo kỹ năng và khu vực của bạn.'
                          : selectedTab == 1
                          ? 'Các đơn hàng bạn đang trong quá trình tiếp nhận và xử lý.'
                          : 'Lịch sử toàn bộ các công việc bạn đã hoàn tất phục vụ.',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (selectedTab == 0 &&
            workAreasLoaded &&
            (closedCities.isNotEmpty || openCities.isEmpty))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (closedCities.isNotEmpty || openCities.isEmpty) ...[
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.deepOrange,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Khu vực làm việc cần cập nhật',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    closedCities.isEmpty
                        ? 'Bạn chưa có khu vực đang hoạt động. Khu vực cũ có thể đã bị đóng hoặc xóa. Vui lòng chọn khu vực khác để tiếp tục nhận việc.'
                        : '${closedCities.join(', ')} đang bảo trì. Công việc tại các khu vực này sẽ không hiển thị. Vui lòng đổi khu vực làm việc.',
                  ),
                ],
                TextButton.icon(
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('Đổi khu vực làm việc'),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PartnerWorkAreas(session: widget.session),
                      ),
                    );
                    if (mounted) await load();
                  },
                ),
              ],
            ),
          ),

        // ERROR ALERT IF ANY
        if (error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 13,
                    ),
                    key: const ValueKey('partner-jobs-error'),
                  ),
                ),
              ],
            ),
          ),

        // =====================================================================
        // 3. TAB CONTENT
        // =====================================================================
        if (selectedTab == 0) ...[
          // TAB 0: VIỆC MỚI PHÙ HỢP
          if (!isOnline)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bedtime_rounded,
                      color: Color(0xFF64748B),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Bạn đang ở chế độ Tạm nghỉ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Bật trực tuyến để hệ thống tự động tìm và gửi thông báo công việc mới phù hợp với bạn.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        setState(() => isOnline = true);
                        load();
                      },
                      icon: const Icon(Icons.flash_on_rounded, size: 18),
                      label: const Text(
                        'Bật trực tuyến ngay',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (loading)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF2563EB),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Đang quét và tải công việc mới…',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (jobs.isEmpty && error == null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Animated radar rings beacon
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x1F10B981),
                        ),
                      ),
                      Container(
                        width: 66,
                        height: 66,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x3310B981),
                        ),
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x4010B981),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Active radar indicator chip
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x9910B981),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Đang quét công việc theo bán kính',
                            style: TextStyle(
                              color: Color(0xFF047857),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Chưa có công việc phù hợp',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Hệ thống đang liên tục quét các yêu cầu dịch vụ trong khu vực hoạt động của bạn. Thông báo sẽ phát chuông ngay khi có đơn mới!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        height: 1.45,
                      ),
                    ),
                  ),
                  // Pro-tip hint
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.tips_and_updates_outlined,
                          size: 15,
                          color: Color(0xFFF59E0B),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mẹo: Bật mạng ổn định và giữ app trực tuyến để nhận thông báo việc mới sớm nhất.',
                            style: TextStyle(
                              fontSize: 11,
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
            for (final job in jobs) _buildJobCard(job),
          ],
        ] else if (selectedTab == 1) ...[
          // TAB 1: CÔNG VIỆC ĐANG LÀM
          if (_activeTasks.isEmpty)
            _buildEmptyActiveTasksCard()
          else
            for (final task in _activeTasks) _buildActiveTaskCard(task),
        ] else ...[
          // TAB 2: LỊCH SỬ HOÀN TẤT
          TaskActivityList(
            key: ValueKey(revision),
            session: widget.session,
            partner: true,
            showHeading: false,
            filter: (task) => ['COMPLETED', 'PAID'].contains(task['status']),
            emptyWidget: _buildEmptyCompletedCard(),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  // ===========================================================================
  // WIDGET BUILDERS
  // ===========================================================================

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) => Column(
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
        ),
      ),
    ],
  );

  Widget _buildEmptyActiveTasksCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Concentric pulse beacon in warm amber
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x1FF59E0B),
                ),
              ),
              Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x33F59E0B),
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x40F59E0B),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Active indicator chip
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 3.5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD97706),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x99D97706),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Sẵn sàng thực hiện nhiệm vụ mới',
                    style: TextStyle(
                      color: Color(0xFFB45309),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'Bạn chưa có công việc nào đang thực hiện',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Bạn chưa nhận đơn hàng nào. Hãy chuyển sang tab "Việc mới" để nhận đơn và bắt đầu công việc.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Button "Xem danh sách việc mới"
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => selectedTab = 0);
              },
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text(
                'Xem danh sách việc mới',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Pro-tip hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  size: 15,
                  color: Color(0xFFF59E0B),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mẹo: Nhận việc sớm và cập nhật trạng thái liên tục giúp khách hàng an tâm và chấm điểm tốt.',
                    style: TextStyle(
                      fontSize: 11,
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
    );
  }

  Widget _buildEmptyCompletedCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Concentric pulse beacon in emerald
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x1F10B981),
                ),
              ),
              Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x3310B981),
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x4010B981),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Status indicator chip
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 3.5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x9910B981),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Lịch sử & doanh thu đã thanh toán',
                    style: TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'Chưa có công việc đã hoàn thành',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Toàn bộ các đơn hàng bạn đã phục vụ xong và nhận thanh toán sẽ được lưu trữ và thống kê chi tiết tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Button "Nhận việc ngay"
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => selectedTab = 0);
              },
              icon: const Icon(Icons.explore_rounded, size: 17),
              label: const Text(
                'Khám phá việc mới ngay',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Pro-tip hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  size: 15,
                  color: Color(0xFF10B981),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mẹo: Hoàn thành đúng hạn và phục vụ chuyên nghiệp giúp tăng tỷ lệ khách hàng đặt lại dịch vụ.',
                    style: TextStyle(
                      fontSize: 11,
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
    );
  }

  Widget _buildTabItem({
    required int index,
    required String label,
    required IconData icon,
    required int badgeCount,
    required Color activeColor,
  }) {
    final active = selectedTab == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => selectedTab = index);
        },
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Color(0x080F172A),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14.5,
                    color: active ? activeColor : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: active ? activeColor : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : const Color(0xFF475569),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard(dynamic job) {
    final title = job['title']?.toString() ?? 'Dịch vụ TaskLy';
    final netAmount =
        job['partner_net_amount'] ?? job['partnerNetAmount'] ?? 0;
    final priceStr = 'Thực nhận: ${_formatVnd(netAmount)}';
    final citySnapshot =
        job['city_snapshot']?.toString() ?? 'Khu vực dịch vụ';
    final durationMinutes = job['estimated_duration_minutes'] ?? 60;
    final scheduledStr = _formatScheduledTime(job['scheduled_at']);
    final fullScheduledStr = _formatFullScheduledTime(job['scheduled_at']);
    final durationStr = _formatDuration(durationMinutes);
    final categoryIcon = _resolveServiceIcon(title);
    final description = job['description']?.toString().trim() ?? '';
    final bool isEligible = job['eligible'] != false;
    final String? reasonCode = job['reasonCode']?.toString();
    final String? reasonMessage = job['reasonMessage']?.toString();
    final String statusTagLabel = job['statusTagLabel']?.toString() ??
        (isEligible
            ? 'Có thể nhận'
            : (reasonCode == 'SCHEDULE_CONFLICT'
                ? 'Trùng lịch'
                : 'Thiếu buffer'));
    final dynamic earliestStart = job['earliestEligibleStartAt'];

    Color tagBg;
    Color tagBorder;
    Color tagText;
    IconData tagIcon;

    if (isEligible) {
      tagBg = const Color(0xFFECFDF5);
      tagBorder = const Color(0xFFA7F3D0);
      tagText = const Color(0xFF047857);
      tagIcon = Icons.check_circle_outline_rounded;
    } else if (reasonCode == 'SCHEDULE_CONFLICT') {
      tagBg = const Color(0xFFFEF2F2);
      tagBorder = const Color(0xFFFECACA);
      tagText = const Color(0xFFDC2626);
      tagIcon = Icons.event_busy_rounded;
    } else if (reasonCode == 'BUFFER_TOO_SHORT') {
      tagBg = const Color(0xFFFFFBEB);
      tagBorder = const Color(0xFFFDE68A);
      tagText = const Color(0xFFD97706);
      tagIcon = Icons.timer_outlined;
    } else {
      tagBg = const Color(0xFFF1F5F9);
      tagBorder = const Color(0xFFCBD5E1);
      tagText = const Color(0xFF64748B);
      tagIcon = Icons.do_not_disturb_on_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEligible ? const Color(0xFFE2E8F0) : const Color(0xFFFED7AA),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: accepting != null || loading
              ? null
              : () => previewJob(job['id'].toString()),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag & Schedule text
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            categoryIcon,
                            size: 13,
                            color: const Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Dịch vụ TaskLy',
                            style: TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        scheduledStr,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Eligibility Status Tag Chip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: tagBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tagBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tagIcon, size: 12, color: tagText),
                          const SizedBox(width: 4),
                          Text(
                            statusTagLabel,
                            style: TextStyle(
                              color: tagText,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Main Title with Service Category Icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Icon(
                          categoryIcon,
                          color: const Color(0xFF0F172A),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16.5,
                              color: Color(0xFF0F172A),
                              height: 1.3,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Organized specs card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    children: [
                      // Location & Budget row
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 15,
                            color: Color(0xFFE11D48),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              citySnapshot,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFEDF2F7),
                        ),
                      ),
                      // Time & Duration row
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 15,
                            color: Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              fullScheduledStr,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timelapse_rounded,
                                size: 13,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                durationStr,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Conflict / Buffer explanation alert if not eligible
                if (!isEligible &&
                    reasonMessage != null &&
                    reasonMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: reasonCode == 'SCHEDULE_CONFLICT'
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: reasonCode == 'SCHEDULE_CONFLICT'
                            ? const Color(0xFFFECACA)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              reasonCode == 'SCHEDULE_CONFLICT'
                                  ? Icons.warning_amber_rounded
                                  : Icons.info_outline_rounded,
                              size: 15,
                              color: reasonCode == 'SCHEDULE_CONFLICT'
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                reasonMessage,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: reasonCode == 'SCHEDULE_CONFLICT'
                                      ? const Color(0xFFB91C1C)
                                      : const Color(0xFFB45309),
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (earliestStart != null) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 21),
                            child: Text(
                              'Ca sớm nhất có thể nhận: ${_formatFullScheduledTime(earliestStart)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 12),

                // Net earnings & Action Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thu nhập nhận được',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              priceStr,
                              style: const TextStyle(
                                fontSize: 18.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF059669),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: accepting != null || loading
                            ? null
                            : () => previewJob(job['id'].toString()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Xem chi tiết',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: accepting != null || loading
                            ? null
                            : () {
                                if (!isEligible) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF2F2),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.event_busy_rounded,
                                              color: Color(0xFFDC2626),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'Không thể nhận việc',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      content: Text(
                                        reasonMessage ??
                                            'Lịch công việc này bị trùng hoặc chưa đảm bảo khoảng đệm tối thiểu 60 phút với công việc khác của bạn.',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          height: 1.45,
                                        ),
                                      ),
                                      actions: [
                                        FilledButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFF2563EB),
                                          ),
                                          child: const Text('Xem việc khác'),
                                        ),
                                      ],
                                    ),
                                  );
                                  return;
                                }
                                accept(job['id'].toString());
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: isEligible
                              ? const Color(0xFF059669)
                              : const Color(0xFF94A3B8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: Icon(
                          isEligible
                              ? Icons.check_circle_outline_rounded
                              : Icons.lock_clock_rounded,
                          size: 16,
                        ),
                        label: Text(
                          isEligible ? 'Nhận việc' : 'Chưa thể nhận',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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

  Widget _buildActiveTaskCard(dynamic task) {
    final otherWork = myActivities.any((item) => item['id'] != task['id'] &&
        ['TASKER_ON_THE_WAY', 'ARRIVED', 'IN_PROGRESS'].contains(item['status']));

    final taskId = task['id']?.toString() ?? '';
    final status = task['status']?.toString() ?? 'ACCEPTED';
    final priceStr =
        'Thực nhận: ${_formatVnd(task['partnerNetAmount'] ?? task['partner_net_amount'])}';
    final isProgressing = progressingTaskId == taskId;
    final nextAction = _nextActionForStatus(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFED7AA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Tag & Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDBA74)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 14,
                          color: Color(0xFFEA580C),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _jobStatusName(status),
                            style: const TextStyle(
                              color: Color(0xFFEA580C),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      priceStr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              task['serviceName'] ?? task['service_name_snapshot'] ?? task['title'] ?? 'Dịch vụ',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),

            if (task['city_snapshot'] != null)
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      task['city_snapshot'].toString(),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),

            Row(
              children: [
                const Icon(Icons.calendar_month_outlined,
                    size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Lịch hẹn: ${_formatFullScheduledTime(task['scheduledAt'] ?? task['scheduled_at'])}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 12),

            // Actions for in-progress task (Always on a single row, never wrapped)
            Row(
              children: [
                if (nextAction != null) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => TaskActivityDetail(
                                session: widget.session,
                                id: taskId,
                                partner: true,
                              ),
                            ),
                          )
                          .then((_) => load());
                    },
                    icon: const Icon(Icons.assignment_outlined, size: 15),
                    label: const Text(
                      'Chi tiết',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E293B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => TaskChatScreen(
                                session: widget.session,
                                taskId: taskId,
                                partner: true,
                                initialServiceName: (task['serviceName'] ?? task['service_name_snapshot'] ?? task['title'])?.toString(),
                              ),
                            ),
                          )
                          .then((_) => load());
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Color(0xFF059669),
                        size: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isProgressing || otherWork
                          ? null
                          : () async {
                              if (status == 'ACCEPTED') {
                                await Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => TaskActivityDetail(session: widget.session, id: taskId, partner: true),
                                ));
                                if (mounted) load();
                              } else {
                                await _progressJob(taskId, status, nextAction.$1);
                              }
                            },
                      icon: Icon(nextAction.$3, size: 16),
                      label: Text(
                        otherWork ? 'Chờ kết thúc việc đang làm' : isProgressing ? 'Đang cập nhật…' : status == 'ACCEPTED' ? 'Điều phối / đến sớm' : nextAction.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => TaskActivityDetail(
                                  session: widget.session,
                                  id: taskId,
                                  partner: true,
                                ),
                              ),
                            )
                            .then((_) => load());
                      },
                      icon: const Icon(Icons.assignment_outlined, size: 15),
                      label: const Text(
                        'Xem chi tiết công việc',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E293B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => TaskChatScreen(
                                session: widget.session,
                                taskId: taskId,
                                partner: true,
                                initialServiceName: task['title']?.toString(),
                              ),
                            ),
                          )
                          .then((_) => load());
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Color(0xFF059669),
                        size: 17,
                      ),
                    ),
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

/// Modern interactive toggle switch button for Partner status (Trực tuyến / Tạm nghỉ).
/// Features a 3D sliding ceramic knob, tactile gradient track, active glow shadow,
/// power icon, and haptic feedback so partners immediately recognize it as a clickable button.
class _PartnerStatusToggleSwitch extends StatelessWidget {
  const _PartnerStatusToggleSwitch({
    required this.isOnline,
    required this.onToggle,
  });

  final bool isOnline;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: isOnline,
      label: isOnline ? 'Chế độ Trực tuyến' : 'Chế độ Tạm nghỉ',
      hint: 'Nhấn để chuyển đổi trạng thái nhận việc',
      child: Tooltip(
        message: isOnline ? 'Nhấn để Tạm nghỉ' : 'Nhấn để Bật trực tuyến',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              onToggle();
            },
            borderRadius: BorderRadius.circular(24),
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              width: 132,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: isOnline
                      ? const [Color(0xFF047857), Color(0xFF10B981)]
                      : const [Color(0xFF334155), Color(0xFF1E293B)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                border: Border.all(
                  color: isOnline
                      ? const Color(0xD96EE7B7)
                      : const Color(0xB364748B),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isOnline
                        ? const Color(0x6610B981)
                        : const Color(0x44000000),
                    blurRadius: isOnline ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                  const BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Text and status indicator
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOutCubic,
                    alignment: isOnline
                        ? const Alignment(-0.65, 0.0)
                        : const Alignment(0.65, 0.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOnline) ...[
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF6EE7B7),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xCC6EE7B7),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Text(
                            isOnline ? 'TRỰC TUYẾN' : 'TẠM NGHỈ',
                            style: TextStyle(
                              color: isOnline
                                  ? Colors.white
                                  : const Color(0xFFE2E8F0),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          if (!isOnline) ...[
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(left: 5),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // 3D Floating sliding knob
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOutCubic,
                    alignment: isOnline
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 29,
                      height: 29,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x47000000),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                          BoxShadow(
                            color: Color(0x3310B981),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.power_settings_new_rounded,
                          size: 16,
                          color: isOnline
                              ? const Color(0xFF047857)
                              : const Color(0xFF64748B),
                        ),
                      ),
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
}
