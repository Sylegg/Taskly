import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../auth/api.dart';
import 'partner_ui_kit.dart';

/// Màn hình Thu nhập & Ví Đối tác (Partner Income, Wallet & Milestone Bonuses)
typedef PartnerIncome = PartnerBenefits;

class PartnerBenefits extends StatefulWidget {
  const PartnerBenefits({super.key, required this.session});
  final Session session;

  @override
  State<PartnerBenefits> createState() => _PartnerBenefitsState();
}

class _PartnerBenefitsState extends State<PartnerBenefits> {
  int balance = 0;
  List<Map<String, dynamic>> _walletHistory = [];
  Map<String, dynamic> _walletConfig = {};
  Timer? _walletTimer;
  bool _walletLoading = true;
  String? _walletError;
  bool _walletFetching = false;

  Future<void> _loadWallet() async {
    if (_walletFetching) return;
    _walletFetching = true;
    try {
      final result = await widget.session.request('/partner/wallet');
      if (!mounted) return;
      setState(() {
        balance = (result['balance'] as num).toInt();
        _walletConfig = Map<String, dynamic>.from(result['config']);
        _walletHistory = (result['transactions'] as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _walletError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _walletError = 'Không thể tải ví. Vui lòng thử lại.');
      }
    } finally {
      _walletFetching = false;
      if (mounted) setState(() => _walletLoading = false);
    }
  }

  String _requestId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  String _statusLabel(String status) => switch (status) {
    'PENDING' => 'Chờ duyệt',
    'APPROVED' => 'Đã duyệt • Chờ chuyển tiền',
    'PAID' => 'Đã chuyển tiền',
    'COMPLETED' => 'Thành công',
    'REJECTED' => 'Đã từ chối',
    _ => status,
  };

  Future<void> _showWalletHistory() async {
    await _loadWallet();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, updateSheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.65,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Lịch sử giao dịch',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Làm mới',
                        onPressed: () async {
                          await _loadWallet();
                          if (context.mounted) updateSheet(() {});
                        },
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  if (_walletError != null) Text(_walletError!),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _walletHistory.isEmpty
                        ? const Center(child: Text('Chưa có giao dịch.'))
                        : ListView.separated(
                            itemCount: _walletHistory.length,
                            separatorBuilder: (_, _) => const Divider(),
                            itemBuilder: (context, index) {
                              final tx = _walletHistory[index];
                              final deposit = tx['type'] == 'DEPOSIT';
                              final at = DateTime.tryParse(
                                tx['created_at'].toString(),
                              )?.toLocal();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  deposit
                                      ? Icons.add_circle_outline_rounded
                                      : Icons.arrow_downward_rounded,
                                  color: const Color(0xFF059669),
                                ),
                                title: Text(deposit ? 'Nạp tiền' : 'Rút tiền'),
                                subtitle: Text(
                                  '${_statusLabel(tx['status'].toString())}\n${at == null ? '' : '${at.day}/${at.month}/${at.year} ${at.hour}:${at.minute.toString().padLeft(2, '0')}'}${tx['note'] == null ? '' : '\n${tx['note']}'}',
                                ),
                                trailing: Text(
                                  '${deposit ? '+' : '-'}${_formatMoney((tx['amount'] as num).toInt())}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
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

  late List<Map<String, dynamic>> _milestones;
  bool _loadingMilestones = true;
  String? _milestoneError;
  bool _fetchingMilestones = false;

  StreamSubscription<void>? _liveSubscription;
  @override
  void dispose() {
    _walletTimer?.cancel();
    _liveSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _liveSubscription = widget.session.liveChanges.listen((_) {
      if (mounted) _loadDynamicMilestones();
    });
    _loadWallet();
    _walletTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadWallet(),
    );
    _milestones = [];
    _loadDynamicMilestones();
  }

  Future<void> _loadDynamicMilestones() async {
    if (_fetchingMilestones) return;
    _fetchingMilestones = true;
    try {
      final res = await widget.session.api.call('/public/partner-milestones');
      if (res is List) {
        final list = res.map((item) {
          final colorHex = (item['color'] as String?) ?? '#2563EB';
          final bgHex = (item['bgColor'] as String?) ?? '#EFF6FF';
          final borderHex = (item['borderColor'] as String?) ?? '#BFDBFE';

          Color parseHex(String hex) {
            final clean = hex.replaceAll('#', '');
            if (clean.length == 6) {
              return Color(int.parse('FF$clean', radix: 16));
            }
            return const Color(0xFF2563EB);
          }

          return {
            'orders': item['orders'] ?? '${item['min_orders']} đơn / ngày',
            'bonus': item['bonus'] ?? '+0đ',
            'icon': item['icon'] ?? '🛵',
            'badge': item['badge'] ?? 'Mốc thưởng',
            'perk': item['perk'] ?? '',
            'color': parseHex(colorHex),
            'bgColor': parseHex(bgHex),
            'borderColor': parseHex(borderHex),
          };
        }).toList();

        if (mounted) {
          setState(() {
            _milestones = list;
            _milestoneError = null;
          });
        }
      }
    } catch (_) {
      // Keep the last server response while offline.
      if (mounted) {
        setState(
          () => _milestoneError = 'Không thể tải mốc thưởng. Vui lòng thử lại.',
        );
      }
    } finally {
      _fetchingMilestones = false;
      if (mounted) setState(() => _loadingMilestones = false);
    }
  }

  static String _formatMoney(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()}đ';
  }

  /// 1. Mốc thưởng nóng khi hoàn thành nhiều đơn mỗi ngày

  /// 2. Chính sách Nạp & Rút tiền minh bạch
  static const walletPolicies = [
    {
      'emoji': '⚡',
      'title': 'Rút tiền về ngân hàng',
      'desc': 'Gửi yêu cầu rút tiền và theo dõi trạng thái duyệt, chuyển tiền trong lịch sử.',
    },
    {
      'emoji': '💳',
      'title': 'Nạp tiền ví hoạt động tiện lợi',
      'desc': 'Nạp tiền vào ví và theo dõi lịch sử giao dịch.',
    },
    {
      'emoji': '🎁',
      'title': '100% Tiền Tip',
      'desc': 'Đối tác giữ trọn vẹn tiền thưởng từ khách, Taskly cam kết 0% chiết khấu tiền tip.',
    },
  ];

  Future<void> _showDepositDialog(BuildContext context) =>
      _showDepositSheet(context);
  Future<void> _showWithdrawDialog(BuildContext context) =>
      _showWithdrawSheet(context);
  void _copyToClipboard(BuildContext ctx, String text, String successMsg) {
    Clipboard.setData(ClipboardData(text: text));
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(successMsg)),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _showDepositSheet(BuildContext context) async {
    final bankName = _walletConfig['bankName']?.toString().isNotEmpty == true
        ? _walletConfig['bankName'].toString()
        : 'Vietcombank';
    final bankAccount = _walletConfig['bankAccount']?.toString().isNotEmpty == true
        ? _walletConfig['bankAccount'].toString()
        : '0988889999';
    final accountOwner = _walletConfig['accountOwner']?.toString().isNotEmpty == true
        ? _walletConfig['accountOwner'].toString()
        : 'CONG TY CO PHAN TASKLY VIET NAM';
    final qrPrefix = _walletConfig['qrPrefix']?.toString().isNotEmpty == true
        ? _walletConfig['qrPrefix'].toString()
        : 'TASKLY NAP';
    final userId = widget.session.user?['id']?.toString() ?? '';
    final memo = '$qrPrefix $userId'.trim();
    final minDeposit = (_walletConfig['minDeposit'] as num?)?.toInt() ?? 50000;
    final maxDeposit = (_walletConfig['maxDeposit'] as num?)?.toInt() ?? 20000000;

    final amount = TextEditingController();
    final form = GlobalKey<FormState>();
    String? error;
    bool submitting = false;
    String? requestId;
    Map<String, dynamic>? pendingBody;
    final presets = [100000, 200000, 500000, 1000000, 2000000];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, updateSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.viewInsetsOf(ctx).bottom + 24,
            ),
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thanh kéo drag handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.add_card_rounded,
                          color: PartnerColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nạp tiền vào ví',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: PartnerColors.navy,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Chuyển khoản theo thông tin ngân hàng bên dưới',
                              style: TextStyle(
                                fontSize: 12,
                                color: PartnerColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: PartnerColors.muted),
                        tooltip: 'Đóng',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Thẻ ngân hàng thụ hưởng chính thức của Taskly (Fintech Card)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
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
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row Tên ngân hàng & Huy hiệu chính thức
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.account_balance_rounded,
                                    size: 15,
                                    color: Color(0xFF0F172A),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    bankName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0x2210B981),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0x6610B981)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 12,
                                    color: Color(0xFF34D399),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Tài khoản chính thức',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF34D399),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

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
                                      fontSize: 10.5,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  SelectableText(
                                    bankAccount,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => _copyToClipboard(
                                ctx,
                                bankAccount,
                                'Đã sao chép số tài khoản: $bankAccount',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.16),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.copy_rounded, size: 14),
                              label: const Text(
                                'Sao chép',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Tên chủ tài khoản
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CHỦ TÀI KHOẢN',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              accountOwner,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF93C5FD),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Nội dung chuyển khoản bắt buộc
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: const Color(0xFF292524),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'NỘI DUNG CHUYỂN KHOẢN (BẮT BUỘC):',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFBBF24),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      memo,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonalIcon(
                                onPressed: () => _copyToClipboard(
                                  ctx,
                                  memo,
                                  'Đã sao chép nội dung chuyển khoản: $memo',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                                  foregroundColor: const Color(0xFFFDE68A),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.copy_rounded, size: 14),
                                label: const Text(
                                  'Sao chép',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Phần nhập số tiền
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Số tiền muốn nạp',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: PartnerColors.navy,
                        ),
                      ),
                      Text(
                        'Tối thiểu ${_formatMoney(minDeposit)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: PartnerColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: amount,
                    enabled: !submitting && pendingBody == null,
                    decoration: InputDecoration(
                      hintText: 'Nhập số tiền nạp vào ví',
                      prefixIcon: const Icon(
                        Icons.payments_outlined,
                        color: PartnerColors.primary,
                      ),
                      suffixText: 'đ',
                      suffixStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: PartnerColors.navy,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: PartnerColors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => updateSheet(() {}),
                    validator: (value) {
                      final number = int.tryParse(value ?? '') ?? 0;
                      if (number < minDeposit || number > maxDeposit) {
                        return 'Nhập số tiền từ ${_formatMoney(minDeposit)} đến ${_formatMoney(maxDeposit)}.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  // Các mốc nạp nhanh (Quick amount chips)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((val) {
                      final isSelected = amount.text == val.toString();
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          amount.text = val.toString();
                          updateSheet(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? PartnerColors.primary.withValues(alpha: 0.12)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? PartnerColors.primary
                                  : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            '+${_formatMoney(val)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? PartnerColors.primary
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // Ghi chú tự động duyệt
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 18,
                          color: Color(0xFF059669),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hệ thống tự động cộng tiền vào ví trong vòng 1-3 phút sau khi giao dịch chuyển khoản thành công.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF065F46),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),

                  const SizedBox(height: 18),

                  // Nút xác nhận nạp tiền
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PartnerColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: submitting
                          ? null
                          : () async {
                              if (!form.currentState!.validate()) return;
                              updateSheet(() {
                                submitting = true;
                                error = null;
                              });
                              requestId ??= _requestId();
                              pendingBody ??= {
                                'requestId': requestId,
                                'amount': int.parse(amount.text),
                              };
                              try {
                                await widget.session.request(
                                  '/partner/wallet/deposit',
                                  method: 'POST',
                                  body: pendingBody,
                                );
                                await _loadWallet();
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Nạp tiền thành công.'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  updateSheet(() {
                                    submitting = false;
                                    error = e is ApiFailure
                                        ? e.message
                                        : 'Không thể gửi yêu cầu. Vui lòng thử lại.';
                                    if (e is ApiFailure &&
                                        e.status >= 400 &&
                                        e.status < 500) {
                                      pendingBody = null;
                                      requestId = null;
                                    }
                                  });
                                }
                              }
                            },
                      child: submitting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('Đang xử lý…'),
                              ],
                            )
                          : const Text(
                              'Xác nhận nạp tiền',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
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

    await Future<void>.delayed(const Duration(milliseconds: 300));
    amount.dispose();
  }

  Future<void> _showWithdrawSheet(BuildContext context) async {
    Map? savedBank;
    try {
      savedBank = await widget.session.request('/partner/bank-account') as Map?;
      if (!context.mounted) return;
      if (savedBank == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vui lòng thêm tài khoản ngân hàng trong mục Tài khoản trước khi rút tiền.',
            ),
          ),
        );
        return;
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không tải được tài khoản ngân hàng. Vui lòng thử lại.',
            ),
          ),
        );
      }
      return;
    }

    final bankName = savedBank['bankName']?.toString() ?? '';
    final accountNumber = savedBank['accountNumber']?.toString() ?? '';
    final accountName = savedBank['accountName']?.toString() ?? '';
    final minWithdraw = (_walletConfig['minWithdraw'] as num?)?.toInt() ?? 50000;
    final maxWithdrawDaily =
        (_walletConfig['maxWithdrawDaily'] as num?)?.toInt() ?? 20000000;
    final withdrawFeePercent =
        (_walletConfig['withdrawFeePercent'] as num?)?.toDouble() ?? 0.0;

    final amount = TextEditingController();
    final form = GlobalKey<FormState>();
    String? error;
    bool submitting = false;
    String? requestId;
    Map<String, dynamic>? pendingBody;
    final presets = [100000, 200000, 500000, 1000000];

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, updateSheet) {
          final int reqAmount = int.tryParse(amount.text) ?? 0;
          final int feeAmount =
              (reqAmount * withdrawFeePercent / 100).ceil();
          final int receiveAmount =
              reqAmount > feeAmount ? reqAmount - feeAmount : 0;

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thanh kéo drag handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),

                    // Header
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.account_balance_rounded,
                            color: Color(0xFF059669),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rút tiền về ngân hàng',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: PartnerColors.navy,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Chuyển về tài khoản ngân hàng chính chủ của đối tác',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: PartnerColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: PartnerColors.muted),
                          tooltip: 'Đóng',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Thẻ số dư ví khả dụng & Hạn mức
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
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
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'SỐ DƯ VÍ KHẢ DỤNG',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFCBD5E1),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 13,
                                      color: Color(0xFF6EE7B7),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Sẵn sàng rút',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF6EE7B7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatMoney(balance),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF6EE7B7),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.speed_rounded,
                                        size: 14,
                                        color: Color(0xFFCBD5E1),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          'Hạn mức: ${_formatMoney(maxWithdrawDaily)}/ngày',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFFE2E8F0),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 14,
                                  color: Colors.white24,
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.percent_rounded,
                                      size: 14,
                                      color: Color(0xFF34D399),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Phí: ${withdrawFeePercent == 0 ? 'Miễn phí' : '$withdrawFeePercent%'}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF34D399),
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

                    const SizedBox(height: 14),

                    // Thẻ tài khoản ngân hàng nhận tiền của Đối tác
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.account_balance_rounded,
                              color: PartnerColors.primary,
                              size: 20,
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
                                      bankName,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: PartnerColors.navy,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Đã liên kết',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  accountNumber,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  accountName,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: PartnerColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Phần nhập số tiền rút
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Số tiền muốn rút',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: PartnerColors.navy,
                          ),
                        ),
                        if (balance > 0)
                          TextButton.icon(
                            onPressed: () {
                              amount.text = balance.toString();
                              updateSheet(() {});
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: const Color(0xFF059669),
                            ),
                            icon: const Icon(Icons.flash_on_rounded, size: 14),
                            label: const Text(
                              'Rút tất cả',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    TextFormField(
                      controller: amount,
                      enabled: !submitting && pendingBody == null,
                      decoration: InputDecoration(
                        hintText: 'Nhập số tiền muốn rút về',
                        prefixIcon: const Icon(
                          Icons.payments_outlined,
                          color: Color(0xFF059669),
                        ),
                        suffixText: 'đ',
                        suffixStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: PartnerColors.navy,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF059669),
                            width: 2,
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => updateSheet(() {}),
                      validator: (value) {
                        final number = int.tryParse(value ?? '') ?? 0;
                        if (number < minWithdraw || number > maxWithdrawDaily) {
                          return 'Nhập số tiền từ ${_formatMoney(minWithdraw)} đến ${_formatMoney(maxWithdrawDaily)}.';
                        }
                        if (number > balance) {
                          return 'Số tiền vượt quá số dư khả dụng (${_formatMoney(balance)}).';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 10),

                    // Các mốc rút nhanh
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presets.map((val) {
                        final isSelected = amount.text == val.toString();
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            amount.text = val.toString();
                            updateSheet(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              _formatMoney(val),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isSelected
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // Bảng tính chi tiết số tiền thực nhận
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Số tiền yêu cầu rút:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: PartnerColors.muted,
                                ),
                              ),
                              Text(
                                _formatMoney(reqAmount),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: PartnerColors.navy,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Phí rút tiền ($withdrawFeePercent%):',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: PartnerColors.muted,
                                ),
                              ),
                              Text(
                                feeAmount == 0
                                    ? 'Miễn phí'
                                    : _formatMoney(feeAmount),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: feeAmount == 0
                                      ? const Color(0xFF059669)
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              height: 1,
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tiền nhận:',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: PartnerColors.navy,
                                ),
                              ),
                              Text(
                                _formatMoney(receiveAmount),
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

                    const SizedBox(height: 12),

                    // Lưu ý xét duyệt
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 17,
                            color: Color(0xFFD97706),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Yêu cầu sẽ được gửi để xét duyệt. Giao dịch hoàn tất khi quản trị viên xác nhận đã chuyển tiền.',
                              style: TextStyle(
                                fontSize: 11.5,
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
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),

                    const SizedBox(height: 18),

                    // Nút gửi yêu cầu rút tiền
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: submitting
                            ? null
                            : () async {
                                if (!form.currentState!.validate()) return;
                                updateSheet(() {
                                  submitting = true;
                                  error = null;
                                });
                                requestId ??= _requestId();
                                pendingBody ??= {
                                  'requestId': requestId,
                                  'amount': int.parse(amount.text),
                                  'bankName': bankName,
                                  'accountName': accountName,
                                  'accountNumber': accountNumber,
                                };
                                try {
                                  await widget.session.request(
                                    '/partner/wallet/withdraw',
                                    method: 'POST',
                                    body: pendingBody,
                                  );
                                  await _loadWallet();
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Đã gửi yêu cầu rút tiền. Vui lòng theo dõi trong Lịch sử.',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    updateSheet(() {
                                      submitting = false;
                                      error = e is ApiFailure
                                          ? e.message
                                          : 'Không thể gửi yêu cầu. Vui lòng thử lại.';
                                      if (e is ApiFailure &&
                                          e.status >= 400 &&
                                          e.status < 500) {
                                        pendingBody = null;
                                        requestId = null;
                                      }
                                    });
                                  }
                                }
                              },
                        child: submitting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Đang gửi…'),
                                ],
                              )
                            : const Text(
                                'Gửi yêu cầu rút tiền',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    amount.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. HERO WALLET & INCOME CARD (Tập trung Thu nhập & Nạp - Rút)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment(-0.8, -0.6),
              end: Alignment(0.9, 0.9),
              colors: [
                Color(0xFF0F172A), // Midnight Slate
                Color(0xFF065F46), // Emerald Green
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x280F172A),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                        color: Color(0xFF6EE7B7),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Ví thu nhập',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showWalletHistory,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6EE7B7),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('Lịch sử'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Số dư khả dụng',
                    style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _walletLoading ? 'Đang tải…' : _formatMoney(balance),
                    style: const TextStyle(
                      color: Color(0xFF6EE7B7),
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_walletError != null)
                    TextButton(
                      onPressed: _loadWallet,
                      child: Text(
                        _walletError!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  // NÚT HÀNH ĐỘNG NẠP TIỀN & RÚT TIỀN
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.16,
                            ),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.28),
                              ),
                            ),
                          ),
                          onPressed: _walletLoading || _walletError != null
                              ? null
                              : () => _showDepositDialog(context),
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 18,
                            color: Color(0xFF34D399),
                          ),
                          label: const Text(
                            'Nạp tiền',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _walletLoading || _walletError != null
                              ? null
                              : () => _showWithdrawDialog(context),
                          icon: const Icon(
                            Icons.arrow_downward_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Rút tiền',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
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

        const SizedBox(height: 18),

        // 2. THƯỞNG MỐC ĐƠN MỖI NGÀY (TRỌNG TÂM)
        PartnerSectionTitle(
          'Thưởng mốc đơn mỗi ngày',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Text(
              'Mốc đang áp dụng',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF059669),
              ),
            ),
          ),
        ),

        if (_loadingMilestones)
          const Center(child: CircularProgressIndicator())
        else if (_milestoneError != null)
          TextButton(
            onPressed: _loadDynamicMilestones,
            child: Text(_milestoneError!),
          )
        else if (_milestones.isEmpty)
          const Text('Chưa có mốc thưởng được công bố.'),
        ..._milestones.map((m) {
          final color = m['color'] as Color;
          final bgColor = m['bgColor'] as Color;
          final borderColor = m['borderColor'] as Color;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x060F172A),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    m['icon'] as String,
                    style: const TextStyle(fontSize: 22),
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
                            m['orders'] as String,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: PartnerColors.navy,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              m['badge'] as String,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        m['perk'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          color: PartnerColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    m['bonus'] as String,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 6),

        // 3. CHÍNH SÁCH NẠP RÚT MINH BẠCH (GỌN NHẸ)
        const PartnerSectionTitle('Chính sách nạp rút & Minh bạch'),
        ...walletPolicies.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PartnerItemTile(
              emoji: p['emoji']!,
              title: p['title']!,
              subtitle: p['desc']!,
            ),
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }
}
