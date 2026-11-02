part of 'customer_view.dart';

class CustomerTopUpDialog extends StatefulWidget {
  const CustomerTopUpDialog({super.key, required this.session});
  final Session session;
  @override
  State<CustomerTopUpDialog> createState() => _CustomerTopUpDialogState();
}

class _CustomerTopUpDialogState extends State<CustomerTopUpDialog> {
  final amount = TextEditingController();
  late Future<dynamic> wallet = widget.session.request('/users/me/wallet');
  bool saving = false;
  bool submitted = false;
  int? requestedAmount;
  String? error;

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  void _copyToClipboard(BuildContext ctx, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> submit(Map data) async {
    if (saving || submitted) return;
    final config = data['config'] as Map;
    final value = requestedAmount ?? int.tryParse(amount.text);
    final min = (config['minDeposit'] as num).toInt();
    final max = (config['maxDeposit'] as num).toInt();
    if (value == null || value < min || value > max) {
      setState(() => error = 'Nhập số tiền từ $min đến $max đ.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
      requestedAmount = value;
    });
    try {
      await widget.session.request(
        '/users/me/wallet/deposit',
        method: 'POST',
        body: {'requestId': data['requestId'], 'amount': value},
      );
      if (mounted) setState(() => submitted = true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF059669),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nạp tiền vào tài khoản',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Chuyển khoản 24/7 • Ghi nhận số dư tự động',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: saving ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
              tooltip: 'Đóng',
            ),
          ],
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: FutureBuilder<dynamic>(
          future: wallet,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 180,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF059669)),
                ),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Không thể tải thông tin nạp tiền: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF334155), fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => setState(
                        () => wallet = widget.session.request('/users/me/wallet'),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              );
            }
            final data = snapshot.data as Map;
            final config = data['config'] as Map;
            final transactions = (data['transactions'] as List?) ?? [];
            final reference = '${config['qrPrefix']} ${data['requestId']}';
            final bankName = config['bankName']?.toString() ?? 'Vietcombank';
            final bankAccount = config['bankAccount']?.toString() ?? '';
            final accountOwner = config['accountOwner']?.toString() ?? '';

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Thẻ số dư ví hiện tại
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0F172A),
                          Color(0xFF065F46),
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F0F172A),
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SỐ DƯ VÍ TASKLY',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFCBD5E1),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Số dư: ${data['balance']} đ',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF6EE7B7),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 12,
                                color: Color(0xFF6EE7B7),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Khách hàng',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6EE7B7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. Ô nhập số tiền nạp
                  TextField(
                    controller: amount,
                    enabled: !saving && requestedAmount == null,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Số tiền nạp (VNĐ)',
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                      hintText: 'Nhập số tiền nạp',
                      helperText:
                          'Từ ${config['minDeposit']} đến ${config['maxDeposit']} đ',
                      helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      prefixIcon: const Icon(
                        Icons.payments_outlined,
                        color: Color(0xFF059669),
                      ),
                      suffixText: 'đ',
                      suffixStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF059669),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 3. Các mốc nạp nhanh (ActionChips)
                  if (requestedAmount == null)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [50000, 100000, 200000, 500000]
                          .where(
                            (v) =>
                                v >= (config['minDeposit'] as num) &&
                                v <= (config['maxDeposit'] as num),
                          )
                          .map((v) {
                            final isSelected = amount.text == '$v';
                            return ActionChip(
                              label: Text(
                                '$v đ',
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 11.5,
                                  color: isSelected ? const Color(0xFF059669) : const Color(0xFF334155),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              backgroundColor: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.5 : 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              onPressed: () {
                                amount.text = '$v';
                                setState(() {});
                              },
                            );
                          })
                          .toList(),
                    ),

                  const SizedBox(height: 14),

                  // 4. Thẻ chuyển khoản ngân hàng TaskLy (Fintech Destination Card)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0F172A),
                          Color(0xFF1E293B),
                        ],
                      ),
                      border: Border.all(color: const Color(0xFF334155)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F0F172A),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hàng tên ngân hàng & Huy hiệu chính thức
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.account_balance_rounded,
                                      size: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        'Ngân hàng: $bankName',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0x2210B981),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0x6610B981)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 11,
                                    color: Color(0xFF34D399),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Chính thức',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF34D399),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Số tài khoản + Nút sao chép
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SỐ TÀI KHOẢN',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  SelectableText(
                                    'Số tài khoản: $bankAccount',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            FilledButton.tonalIcon(
                              onPressed: () => _copyToClipboard(
                                context,
                                bankAccount,
                                'Đã sao chép số tài khoản: $bankAccount',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.16),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.copy_rounded, size: 13),
                              label: const Text(
                                'Sao chép',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Chủ tài khoản
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CHỦ TÀI KHOẢN',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Chủ tài khoản: $accountOwner',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6EE7B7),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Khối Nội dung chuyển khoản bắt buộc
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF292524),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Nội dung chuyển khoản:',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFBBF24),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () async {
                                      await Clipboard.setData(
                                        ClipboardData(
                                          text: '$bankAccount\n$reference',
                                        ),
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Đã sao chép thông tin chuyển khoản'),
                                            behavior: SnackBarBehavior.floating,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      foregroundColor: const Color(0xFFFDE68A),
                                    ),
                                    icon: const Icon(Icons.copy, size: 13),
                                    label: const Text(
                                      'Sao chép',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              SelectableText(
                                reference,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Lưu ý chuyển khoản đúng số tiền
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: Color(0xFFD97706),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Chuyển khoản đúng số tiền và nội dung trên. Số dư được cộng sau khi admin xác nhận đã nhận tiền.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF92400E),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Nút xác nhận chuyển khoản
                  if (submitted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF059669),
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Đã gửi yêu cầu nạp tiền, đang chờ xác nhận.',
                              style: TextStyle(
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: saving ? null : () => submit(data),
                        child: saving
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Đang gửi…'),
                                ],
                              )
                            : const Text(
                                'Tôi đã chuyển khoản',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ),

                  // 5. Lịch sử nạp tiền
                  Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: Color(0xFF0F172A),
                      ),
                      const SizedBox(width: 5),
                      const Expanded(
                        child: Text(
                          'Lịch sử nạp tiền',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (transactions.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${transactions.length} giao dịch',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (transactions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Text(
                          'Chưa có giao dịch nạp tiền.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  else
                    ...transactions.map((tx) {
                      final status = tx['status']?.toString() ?? 'PENDING';
                      final statusColor = switch (status) {
                        'COMPLETED' => const Color(0xFF059669),
                        'REJECTED' => Colors.red,
                        _ => const Color(0xFFD97706),
                      };
                      final statusBg = switch (status) {
                        'COMPLETED' => const Color(0xFFECFDF5),
                        'REJECTED' => const Color(0xFFFEF2F2),
                        _ => const Color(0xFFFFFBEB),
                      };
                      final statusLabel = switch (status) {
                        'COMPLETED' => 'Thành công',
                        'REJECTED' => 'Từ chối',
                        _ => 'Chờ duyệt',
                      };

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.arrow_downward_rounded,
                                color: Color(0xFF059669),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '+${tx['amount']} đ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${tx['created_at']}${tx['reference_code'] != null ? ' • ${tx['reference_code']}' : ''}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF64748B),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}
