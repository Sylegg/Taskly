import 'dart:async';

import 'package:flutter/material.dart';

import '../app/customer_controller.dart';
import '../core/theme.dart';
import '../domain/booking_draft.dart';

/// Displays the persisted booking draft without treating it as a posted job.
class BookingDraftActivity extends StatefulWidget {
  const BookingDraftActivity({
    super.key,
    required this.controller,
    this.hideWhenEmpty = false,
    this.showHeading = true,
    this.following,
  });
  final CustomerController controller;
  final bool hideWhenEmpty;
  final bool showHeading;
  final Widget Function(int count)? following;

  @override
  State<BookingDraftActivity> createState() => _BookingDraftActivityState();
}

class _BookingDraftActivityState extends State<BookingDraftActivity> {
  late Future<List<CustomerBookingDraft>> _draft = _load();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<List<CustomerBookingDraft>> _load() async {
    final repo = widget.controller.repository;
    if (repo is CustomerPendingBookings) {
      return (repo as CustomerPendingBookings).pendingBookings();
    }
    final draft = await (repo as CustomerBookingDrafts).restoreBookingDraft();
    return draft == null ? [] : [draft];
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<CustomerBookingDraft>>(
        future: _draft,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox.shrink();
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  const Text(
                    'Không thể tải hoạt động. Vui lòng thử lại.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _draft = _load();
                    }),
                    child: const Text('Thử lại'),
                  ),
                  if (widget.following != null) widget.following!(1),
                ],
              ),
            );
          }
          final drafts = snapshot.data ?? [];
          if (drafts.isEmpty) {
            return widget.following?.call(0) ?? const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showHeading)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    'Đơn của bạn',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ...drafts.map((draft) => draftCard(context, draft)),
              if (widget.following != null) widget.following!(drafts.length),
            ],
          );
        },
      );
  String _formatDateTime(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(dt.hour)}:${pad(dt.minute)}, ${pad(dt.day)}/${pad(dt.month)}/${dt.year}';
  }

  Widget _buildStatusBadge(bool expired) {
    final label = expired ? 'Giờ hẹn đã qua' : 'Chưa hoàn thành';
    final foreground =
        expired ? const Color(0xFFDC2626) : const Color(0xFFEA580C);
    final background =
        expired ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED);
    final border =
        expired ? const Color(0xFFFECACA) : const Color(0xFFFFEDD5);
    final icon =
        expired ? Icons.timer_off_outlined : Icons.pending_actions_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    CustomerBookingDraft draft,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Hủy đơn đặt dịch vụ?'),
        content: const Text(
          'Bạn có chắc chắn muốn hủy đơn đặt dịch vụ này không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Không',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final repo = widget.controller.repository;
      if (repo is CustomerPendingBookings && draft.pendingId != null) {
        await (repo as CustomerPendingBookings).deletePendingBooking(
          draft.pendingId!,
        );
      } else {
        await (repo as CustomerBookingDrafts).deleteBookingDraft();
      }
      if (mounted) {
        setState(() {
          _draft = _load();
        });
      }
    }
  }

  Widget draftCard(BuildContext context, CustomerBookingDraft draft) {
    final expired =
        draft.scheduledAt != null &&
        !draft.scheduledAt!.isAfter(DateTime.now());
    final selectedServices = draft.selectedServiceIds
        .map(
          (id) => widget.controller.data!.services
              .where((s) => s.id == id)
              .firstOrNull
              ?.name,
        )
        .whereType<String>()
        .toList();
    final displayName = selectedServices.isNotEmpty
        ? selectedServices.join(', ')
        : (widget.controller.data!.services
                .where((s) => s.id == draft.serviceId)
                .firstOrNull
                ?.name ??
            'Dịch vụ đã lưu');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => widget.controller.startCreate(
            resumeBooking: true,
            pendingBookingId: draft.pendingId,
          ),
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
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFA7F3D0),
                        ),
                      ),
                      child: const Icon(
                        Icons.handyman_outlined,
                        color: Color(0xFF059669),
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            draft.scheduledAt != null
                                ? 'Hẹn: ${_formatDateTime(draft.scheduledAt!)}'
                                : 'Chưa chọn giờ hẹn',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(expired),
                  ],
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
                        expired
                            ? Icons.schedule_outlined
                            : Icons.touch_app_outlined,
                        size: 16,
                        color: const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          expired
                              ? 'Sửa giờ hẹn để tiếp tục đặt'
                              : 'Chạm để tiếp tục đặt dịch vụ',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Hủy đơn đặt dịch vụ',
                        child: InkWell(
                          onTap: () => _confirmCancel(context, draft),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Hủy',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              expired ? 'Sửa giờ' : 'Tiếp tục',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 15,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
