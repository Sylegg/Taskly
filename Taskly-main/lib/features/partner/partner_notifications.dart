import 'dart:async';
import 'package:flutter/material.dart';

import '../../auth/api.dart';
import '../task_activity.dart';
import '../task_chat.dart';
import 'partner_bank.dart';
import 'partner_uniform_shop.dart';
import 'recruitment_office_visit.dart';

/// Trang Thông báo Đối tác (Dành riêng, giống 1000% giao diện với Khách hàng).
class PartnerNotificationPage extends StatefulWidget {
  const PartnerNotificationPage({
    super.key,
    required this.session,
    this.onNotificationRead,
  });

  final Session session;
  final VoidCallback? onNotificationRead;

  @override
  State<PartnerNotificationPage> createState() =>
      _PartnerNotificationPageState();
}

class _PartnerNotificationPageState extends State<PartnerNotificationPage> {
  int _selectedFilter = 0; // 0: Tất cả, 1: Chưa đọc
  bool _loading = true;
  bool _refreshing = false;
  List<Map<String, dynamic>> _notifications = [];
  String? _error;
  StreamSubscription<void>? _liveSub;

  @override
  void initState() {
    super.initState();
    _liveSub = widget.session.liveChanges.listen((_) {
      if (mounted) _load(silent: true);
    });
    _load();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await widget.session.request('/partner/notifications');
      if (mounted) {
        setState(() {
          _notifications = (items as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _loading = false;
          _refreshing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải thông báo. Vui lòng thử lại.';
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _refreshing = true);
    await _load(silent: true);
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _handleReadAll() async {
    final unread = _notifications
        .where((n) => n['read_at'] == null && n['read'] != true)
        .toList();
    if (unread.isEmpty) return;

    final nowIso = DateTime.now().toIso8601String();
    setState(() {
      for (final n in _notifications) {
        if (n['read_at'] == null && n['read'] != true) {
          n['read_at'] = nowIso;
          n['read'] = true;
        }
      }
    });
    widget.onNotificationRead?.call();

    try {
      await widget.session.request(
        '/partner/notifications/read-all',
        method: 'POST',
      );
    } catch (_) {
      try {
        final ids = unread.map((e) => e['id'].toString()).toList();
        await widget.session.request(
          '/partner/notifications/read',
          method: 'POST',
          body: {'ids': ids},
        );
      } catch (_) {}
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final taskId = (item['task_id'] ?? item['taskId'] ?? '').toString();
    final title = (item['title'] ?? '').toString();
    final message = (item['message'] ?? '').toString();

    final isUnread = item['read_at'] == null && item['read'] != true;
    if (isUnread) {
      setState(() {
        item['read_at'] = DateTime.now().toIso8601String();
        item['read'] = true;
      });
      widget.onNotificationRead?.call();
      try {
        await widget.session.request(
          '/partner/notifications/$id/read',
          method: 'POST',
        );
      } catch (_) {
        try {
          await widget.session.request(
            '/partner/notifications/read',
            method: 'POST',
            body: {
              'ids': [id],
            },
          );
        } catch (_) {}
      }
    }

    if (!mounted) return;

    if (taskId.isNotEmpty) {
      final isChat = '$title $message'.toLowerCase().contains('nhắn') ||
          '$title $message'.toLowerCase().contains('chat');
      if (isChat) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TaskChatScreen(
              session: widget.session,
              taskId: taskId,
              partner: true,
            ),
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TaskActivityDetail(
              session: widget.session,
              id: taskId,
              partner: true,
            ),
          ),
        );
      }
      if (mounted) _load(silent: true);
      return;
    }

    final lower = '$title $message'.toLowerCase();
    if (lower.contains('đồng phục')) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PartnerUniformShop(session: widget.session),
        ),
      );
      return;
    }
    if (lower.contains('ngân hàng') || lower.contains('tài khoản nhận')) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PartnerBank(session: widget.session),
        ),
      );
      return;
    }
    if (lower.contains('văn phòng') || lower.contains('hub')) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecruitmentOfficeVisit(session: widget.session),
        ),
      );
      return;
    }
  }

  ({IconData icon, Color bgColor, Color iconColor, String categoryLabel})
  _getStyle(String title, [String message = '']) {
    final lower = '$title $message'.toLowerCase();
    if (lower.contains('hủy') || lower.contains('cancel')) {
      return (
        icon: Icons.cancel_outlined,
        bgColor: const Color(0xFFFFF1F2),
        iconColor: const Color(0xFFE11D48),
        categoryLabel: 'Đã hủy',
      );
    }
    if (lower.contains('hoàn tiền') ||
        lower.contains('refund') ||
        lower.contains('tiền mặt') ||
        lower.contains('thanh toán') ||
        lower.contains('thu nhập') ||
        lower.contains('thưởng') ||
        lower.contains('ví')) {
      return (
        icon: Icons.payments_outlined,
        bgColor: const Color(0xFFFFFBEB),
        iconColor: const Color(0xFFD97706),
        categoryLabel: 'Thu nhập & Thưởng',
      );
    }
    if (lower.contains('trên đường') || lower.contains('di chuyển')) {
      return (
        icon: Icons.two_wheeler_rounded,
        bgColor: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF0D9488),
        categoryLabel: 'Đang đến',
      );
    }
    if (lower.contains('đã đến')) {
      return (
        icon: Icons.person_pin_circle_rounded,
        bgColor: const Color(0xFFFAF5FF),
        iconColor: const Color(0xFF7C3AED),
        categoryLabel: 'Đã đến nơi',
      );
    }
    if (lower.contains('bắt đầu')) {
      return (
        icon: Icons.play_circle_outline_rounded,
        bgColor: const Color(0xFFEEF2FF),
        iconColor: const Color(0xFF4F46E5),
        categoryLabel: 'Đang thực hiện',
      );
    }
    if (lower.contains('hoàn thành') || lower.contains('hoàn tất')) {
      return (
        icon: Icons.task_alt_rounded,
        bgColor: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF059669),
        categoryLabel: 'Hoàn tất',
      );
    }
    if (lower.contains('nhận đơn') ||
        lower.contains('đã nhận') ||
        lower.contains('nhận việc') ||
        lower.contains('công việc')) {
      return (
        icon: Icons.handshake_rounded,
        bgColor: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        categoryLabel: 'Công việc',
      );
    }
    if (lower.contains('nhắn') || lower.contains('tin nhắn')) {
      return (
        icon: Icons.chat_bubble_outline_rounded,
        bgColor: const Color(0xFFFAF5FF),
        iconColor: const Color(0xFF9333EA),
        categoryLabel: 'Tin nhắn',
      );
    }
    if (lower.contains('hỗ trợ') || lower.contains('chăm sóc')) {
      return (
        icon: Icons.support_agent_rounded,
        bgColor: const Color(0xFFECFEFF),
        iconColor: const Color(0xFF0891B2),
        categoryLabel: 'Hỗ trợ CSKH',
      );
    }
    return (
      icon: Icons.receipt_long_rounded,
      bgColor: const Color(0xFFECFDF5),
      iconColor: const Color(0xFF059669),
      categoryLabel: 'Thông báo',
    );
  }

  DateTime _parseTime(dynamic val) {
    if (val is DateTime) return val;
    if (val is String && val.isNotEmpty) {
      final parsed = DateTime.tryParse(val);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24 &&
        now.day == time.day &&
        now.month == time.month &&
        now.year == time.year) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return 'Hôm nay, $h:$m';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.day == time.day &&
        yesterday.month == time.month &&
        yesterday.year == time.year) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return 'Hôm qua, $h:$m';
    }
    final d = time.day.toString().padLeft(2, '0');
    final mo = time.month.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$d/$mo/${time.year} • $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final inAppNotifications = _notifications
        .where((item) => (item['channel'] ?? 'IN_APP') == 'IN_APP')
        .toList();
    final unreadCount = inAppNotifications
        .where((n) => n['read_at'] == null && n['read'] != true)
        .length;
    final displayedList = _selectedFilter == 1
        ? inAppNotifications
            .where((n) => n['read_at'] == null && n['read'] != true)
            .toList()
        : inAppNotifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: const Color(0xFF0F172A),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Thông báo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF059669)),
              )
            : RefreshIndicator(
                color: const Color(0xFF059669),
                onRefresh: _handleRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Header Bar: Tiêu đề, số lượng & Nút thao tác (Giống Customer 100%)
                      Row(
                        children: [
                          const Text(
                            'Thông báo',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.4,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFA7F3D0),
                                ),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (unreadCount > 0)
                            IconButton(
                              tooltip: 'Đã đọc tất cả',
                              onPressed: _handleReadAll,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              icon: const Icon(
                                Icons.done_all_rounded,
                                size: 20,
                                color: Color(0xFF059669),
                              ),
                            ),
                          IconButton(
                            tooltip: 'Tải lại thông báo',
                            onPressed: _refreshing ? null : _handleRefresh,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: _refreshing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF059669),
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    size: 20,
                                    color: Color(0xFF64748B),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 2. Bộ lọc Tabs (Tất cả / Chưa đọc) (Giống Customer 100%)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterChip(
                            label: 'Tất cả (${inAppNotifications.length})',
                            isSelected: _selectedFilter == 0,
                            onTap: () => setState(() => _selectedFilter = 0),
                          ),
                          _buildFilterChip(
                            label: 'Chưa đọc ($unreadCount)',
                            isSelected: _selectedFilter == 1,
                            onTap: () => setState(() => _selectedFilter = 1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Color(0xFFE11D48),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFBE123C),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),

                      // 3. Danh sách thông báo hoặc Empty state (Giống Customer 100%)
                      if (displayedList.isEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(vertical: 24),
                          padding: const EdgeInsets.symmetric(
                            vertical: 40,
                            horizontal: 24,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                child: Icon(
                                  _selectedFilter == 1
                                      ? Icons.done_all_rounded
                                      : Icons.notifications_none_rounded,
                                  size: 32,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedFilter == 1
                                    ? 'Bạn đã đọc hết thông báo'
                                    : 'Chưa có thông báo nào',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedFilter == 1
                                    ? 'Không có thông báo mới nào chưa đọc.'
                                    : 'Cập nhật việc làm mới, tin nhắn từ khách hàng và các thông tin thu nhập sẽ xuất hiện tại đây.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  height: 1.45,
                                ),
                              ),
                              if (_selectedFilter == 0) ...[
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(
                                    Icons.work_outline_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Xem danh sách công việc'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: displayedList.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final n = displayedList[index];
                            final title = (n['title'] ?? '').toString();
                            final message = (n['message'] ?? '').toString();
                            final taskId = (n['task_id'] ?? n['taskId'] ?? '')
                                .toString();
                            final isUnread =
                                n['read_at'] == null && n['read'] != true;
                            final style = _getStyle(title, message);
                            final time = _parseTime(
                              n['created_at'] ?? n['at'] ?? n['time'],
                            );

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _handleNotificationTap(n),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isUnread
                                        ? const Color(0xFFF9FCFA)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isUnread
                                          ? const Color(0xFFA7F3D0)
                                          : const Color(0xFFE2E8F0),
                                      width: isUnread ? 1.4 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.02,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Left Icon Badge
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: style.bgColor,
                                          borderRadius: BorderRadius.circular(
                                            13,
                                          ),
                                          border: Border.all(
                                            color: style.iconColor.withValues(
                                              alpha: 0.2,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          style.icon,
                                          color: style.iconColor,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Content
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: style.bgColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      style.categoryLabel,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: style.iconColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  _formatTime(time),
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    color: Color(0xFF94A3B8),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (isUnread) ...[
                                                  const SizedBox(width: 5),
                                                  Container(
                                                    width: 7,
                                                    height: 7,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: Color(
                                                            0xFF059669,
                                                          ),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: isUnread
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: isUnread
                                                    ? const Color(0xFF0F172A)
                                                    : const Color(0xFF334155),
                                                height: 1.4,
                                              ),
                                            ),
                                            if (message.isNotEmpty &&
                                                message != title) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                message,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B),
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                            if (taskId.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFF1F5F9,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '#${taskId.length > 8 ? taskId.substring(0, 8) : taskId}',
                                                      style: const TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xFF64748B,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: const [
                                                      Text(
                                                        'Chi tiết',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                            0xFF059669,
                                                          ),
                                                        ),
                                                      ),
                                                      Icon(
                                                        Icons
                                                            .chevron_right_rounded,
                                                        size: 15,
                                                        color: Color(
                                                          0xFF059669,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:
              isSelected ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

/// Backward-compatible widget & helper for Partner Notification View
class PartnerNotificationView extends StatelessWidget {
  const PartnerNotificationView({
    super.key,
    required this.session,
    this.onNotificationRead,
    this.onClose,
  });

  final Session session;
  final VoidCallback? onNotificationRead;
  final VoidCallback? onClose;

  /// Open as a dedicated full screen page (standard page routing)
  static Future<void> openPage(
    BuildContext context,
    Session session, {
    VoidCallback? onNotificationRead,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PartnerNotificationPage(
          session: session,
          onNotificationRead: onNotificationRead,
        ),
      ),
    );
  }

  /// Backward-compatible helper: now routes directly to dedicated page per user requirement
  static Future<void> showSheet(
    BuildContext context,
    Session session, {
    VoidCallback? onNotificationRead,
  }) {
    return openPage(context, session, onNotificationRead: onNotificationRead);
  }

  @override
  Widget build(BuildContext context) {
    return PartnerNotificationPage(
      session: session,
      onNotificationRead: onNotificationRead,
    );
  }
}
