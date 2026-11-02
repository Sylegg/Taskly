import 'package:flutter/material.dart';

import '../../auth/api.dart';

bool needsPartnerPaymentConfirmation(Map task) =>
    const ['COMPLETED', 'PAID'].contains(task['status']) &&
    task['partnerPaymentConfirmedAt'] == null;

bool isPartnerHistoryTask(Map task) =>
    const [
      'COMPLETED',
      'PAID',
      'CANCELLED',
      'EXPIRED',
      'REFUNDED',
    ].contains(task['status']) &&
    !needsPartnerPaymentConfirmation(task);

class PartnerPaymentConfirmation extends StatefulWidget {
  const PartnerPaymentConfirmation({
    super.key,
    required this.session,
    required this.task,
    required this.onConfirmed,
    this.iconOnly = false,
  });
  final Session session;
  final Map task;
  final Future<void> Function() onConfirmed;
  final bool iconOnly;
  @override
  State<PartnerPaymentConfirmation> createState() =>
      _PartnerPaymentConfirmationState();
}

class _PartnerPaymentConfirmationState
    extends State<PartnerPaymentConfirmation> {
  bool _sending = false;
  String? _error;
  Future<void> _confirm() async {
    final cash =
        widget.task['paymentMethod'] == 'CASH' &&
        widget.task['paymentStatus'] == 'AWAITING_CASH';
    final amount = (widget.task['cashAmountDue'] ?? 0)
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đã nhận tiền'),
        content: Text(
          cash
              ? 'Bạn đã nhận đủ $amount đ từ khách hàng?'
              : 'Bạn xác nhận đã nhận tiền cho công việc này?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Chưa nhận'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đã nhận tiền'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.session.request(
        '/partner/jobs/${widget.task['id']}/payment-received',
        method: 'POST',
      );
      await widget.onConfirmed();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.iconOnly
        ? IconButton(
            key: const ValueKey('partner-payment-action'),
            tooltip: 'Xác nhận đã nhận tiền',
            onPressed: _sending ? null : _confirm,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: const EdgeInsets.all(7),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: const Color(0xFF2563EB),
            ),
            icon: const Icon(Icons.payments_outlined, size: 19),
          )
        : FilledButton(
            key: const ValueKey('partner-payment-action'),
            onPressed: _sending ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _sending ? 'Đang xác nhận…' : 'Xác nhận đã nhận tiền',
              textAlign: TextAlign.center,
            ),
          );
    if (_error == null)
      return widget.iconOnly
          ? action
          : Tooltip(message: 'Xác nhận đã nhận tiền', child: action);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        action,
        Text(_error!, style: const TextStyle(color: Colors.red)),
      ],
    );
  }
}
