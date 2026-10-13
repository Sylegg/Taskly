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
      title: const Text('Nạp tiền vào tài khoản'),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<dynamic>(
          future: wallet,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Không thể tải thông tin nạp tiền: ${snapshot.error}'),
                  TextButton(
                    onPressed: () => setState(
                      () => wallet = widget.session.request('/users/me/wallet'),
                    ),
                    child: const Text('Thử lại'),
                  ),
                ],
              );
            }
            final data = snapshot.data as Map;
            final config = data['config'] as Map;
            final transactions = (data['transactions'] as List?) ?? [];
            final reference = '${config['qrPrefix']} ${data['requestId']}';
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Số dư: ${data['balance']} đ'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amount,
                    enabled: !saving && requestedAmount == null,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Số tiền nạp (VNĐ)',
                      helperText:
                          'Từ ${config['minDeposit']} đến ${config['maxDeposit']} đ',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (requestedAmount == null)
                    Wrap(
                      spacing: 8,
                      children: [50000, 100000, 200000, 500000]
                          .where(
                            (v) =>
                                v >= (config['minDeposit'] as num) &&
                                v <= (config['maxDeposit'] as num),
                          )
                          .map(
                            (v) => ActionChip(
                              label: Text('$v đ'),
                              onPressed: () => amount.text = '$v',
                            ),
                          )
                          .toList(),
                    ),
                  const Divider(height: 24),
                  Text('Ngân hàng: ${config['bankName']}'),
                  SelectableText('Số tài khoản: ${config['bankAccount']}'),
                  Text('Chủ tài khoản: ${config['accountOwner']}'),
                  const SizedBox(height: 8),
                  const Text('Nội dung chuyển khoản:'),
                  SelectableText(reference),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: '${config['bankAccount']}\n$reference',
                        ),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép thông tin chuyển khoản'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Sao chép'),
                  ),
                  const Text(
                    'Chuyển khoản đúng số tiền và nội dung trên. Số dư được cộng sau khi admin xác nhận đã nhận tiền.',
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (submitted)
                    const Text(
                      'Đã gửi yêu cầu nạp tiền, đang chờ xác nhận.',
                      style: TextStyle(color: Color(0xFF059669)),
                    )
                  else
                    FilledButton(
                      onPressed: saving ? null : () => submit(data),
                      child: Text(saving ? 'Đang gửi…' : 'Tôi đã chuyển khoản'),
                    ),
                  const Divider(height: 24),
                  const Text(
                    'Lịch sử nạp tiền',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (transactions.isEmpty)
                    const Text('Chưa có giao dịch nạp tiền.'),
                  for (final tx in transactions)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${tx['amount']} đ'),
                      subtitle: Text(
                        '${tx['created_at']}\n${tx['reference_code'] ?? ''}',
                      ),
                      trailing: Text(switch (tx['status']) {
                        'COMPLETED' => 'Thành công',
                        'REJECTED' => 'Từ chối',
                        _ => 'Chờ duyệt',
                      }),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}
