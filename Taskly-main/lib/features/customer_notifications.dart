import 'package:flutter/material.dart';
import '../app/customer_controller.dart';
import '../domain/models.dart';
import '../data/api_customer_repository.dart';
import 'task_activity.dart';
import 'task_chat.dart';

class CustomerNotificationView extends StatefulWidget {
  const CustomerNotificationView({super.key, required this.controller});
  final CustomerController controller;

  @override
  State<CustomerNotificationView> createState() =>
      _CustomerNotificationViewState();
}

class _CustomerNotificationViewState extends State<CustomerNotificationView> {
  int _selectedFilter = 0; // 0: Tất cả, 1: Chưa đọc
  bool _refreshing = false;

  CustomerController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      c.reloadNotifications();
    });
  }

  Future<void> _handleRefresh() async {
    setState(() => _refreshing = true);
    await c.reloadNotifications();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _handleReadAll() async {
    await c.readAllNotifications();
  }

  ({IconData icon, Color bgColor, Color iconColor, String categoryLabel})
  _getStyle(String title) {
    final lower = title.toLowerCase();
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
        lower.contains('thanh toán')) {
      return (
        icon: Icons.payments_outlined,
        bgColor: const Color(0xFFFFFBEB),
        iconColor: const Color(0xFFD97706),
        categoryLabel: 'Thanh toán',
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
    if (lower.contains('nhận đơn') || lower.contains('đã nhận')) {
      return (
        icon: Icons.handshake_rounded,
        bgColor: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        categoryLabel: 'Đối tác nhận việc',
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
      categoryLabel: 'Đơn dịch vụ',
    );
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

  void _onNotificationTap(AppNotification n) async {
    await c.readNotification(n);
    if (!mounted) return;
    if (n.taskId.isNotEmpty && c.repository is ApiCustomerRepository) {
      final isChat = n.title.toLowerCase().contains('nhắn') ||
          n.title.toLowerCase().contains('chat');
      if (isChat) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TaskChatScreen(
              session: (c.repository as ApiCustomerRepository).session,
              taskId: n.taskId,
              partner: false,
            ),
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TaskActivityDetail(
              session: (c.repository as ApiCustomerRepository).session,
              id: n.taskId,
            ),
          ),
        );
      }
      if (mounted) c.reloadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allNotifications = c.data?.notifications ?? <AppNotification>[];
    final unreadCount = allNotifications.where((n) => !n.read).length;
    final displayedList = _selectedFilter == 1
        ? allNotifications.where((n) => !n.read).toList()
        : allNotifications;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header Bar: Tiêu đề, số lượng & Nút thao tác
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
                  border: Border.all(color: const Color(0xFFA7F3D0)),
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
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
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
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: _refreshing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
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

        // 2. Bộ lọc Tabs (Tất cả / Chưa đọc)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip(
              label: 'Tất cả (${allNotifications.length})',
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

        // 3. Danh sách thông báo hoặc Empty state
        if (displayedList.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 24),
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
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
                      : 'Cập nhật tiến độ đơn hàng, tin nhắn từ đối tác và các thông tin dịch vụ sẽ xuất hiện tại đây.',
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
                    onPressed: () => c.open(PageId.services),
                    icon: const Icon(Icons.explore_outlined, size: 18),
                    label: const Text('Khám phá dịch vụ'),
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
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final n = displayedList[index];
              final style = _getStyle(n.title);
              final isUnread = !n.read;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onNotificationTap(n),
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
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Icon Badge
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: style.bgColor,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: style.iconColor.withValues(alpha: 0.2),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: style.bgColor,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        style.categoryLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: style.iconColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatTime(n.at),
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
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF059669),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                n.title,
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
                              if (n.taskId.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '#${n.taskId.length > 8 ? n.taskId.substring(0, 8) : n.taskId}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text(
                                          'Chi tiết',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 15,
                                          color: Color(0xFF059669),
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
          color: isSelected ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
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
