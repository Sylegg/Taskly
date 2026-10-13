import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/api.dart';
import '../../core/theme.dart';
import '../../shared/vietnamese_banks.dart';

/// Màn hình quản lý tài khoản ngân hàng của Đối tác.
/// Quy tắc bảo mật:
/// - Đối tác chỉ được liên kết DUY NHẤT 01 tài khoản ngân hàng.
/// - Không được thêm tài khoản thứ 2.
/// - Sau khi liên kết, tài khoản ngân hàng được CỐ ĐỊNH / KHÓA BẢO MẬT, không thể tự ý sửa đổi.
class PartnerBank extends StatefulWidget {
  const PartnerBank({super.key, required this.session});
  final Session session;

  @override
  State<PartnerBank> createState() => _PartnerBankState();
}

class _PartnerBankState extends State<PartnerBank> {
  final _formKey = GlobalKey<FormState>();
  final _bankController = TextEditingController();
  final _ownerController = TextEditingController();
  final _accountController = TextEditingController();

  bool _busy = true;
  bool _saving = false;
  String? _error;
  bool _hasLinkedBank = false;
  bool _loadFailed = false;
  late VietnameseBank _selectedBank;

  @override
  void initState() {
    super.initState();
    _selectedBank = kVietnameseBanks.first;
    _ownerController.text = (widget.session.user?['fullName']?.toString() ?? '')
        .trim()
        .toUpperCase();
    _load();
  }

  @override
  void dispose() {
    _bankController.dispose();
    _ownerController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _busy = true; _error = null; _loadFailed = false; });
    try {
      final profile = await widget.session.request('/users/me');
      if (!mounted) return;
      if (profile is Map) {
        _ownerController.text =
            (profile['fullName']?.toString() ?? '').trim().toUpperCase();
      }
      final data = await widget.session.request('/partner/bank-account');
      if (!mounted) return;
      if (data is Map) {
        final bName = data['bankName']?.toString().trim() ?? '';
        final oName = data['accountName']?.toString().trim() ?? '';
        final aNum = data['accountNumber']?.toString().trim() ?? '';
        if (bName.isNotEmpty && aNum.isNotEmpty) {
          _bankController.text = bName;
          _ownerController.text = oName;
          _accountController.text = aNum;
          _hasLinkedBank = true;
          _selectedBank = findVietnameseBank(bName);
        }
      }
    } catch (_) {
      _loadFailed = true;
      _error = 'Không thể tải thông tin ngân hàng. Vui lòng thử lại sau.';
    }
    if (mounted) setState(() => _busy = false);
  }

  void _onBankSelected(VietnameseBank b) {
    setState(() {
      _selectedBank = b;
      if (_accountController.text.length > b.maxDigits) {
        _accountController.text = _accountController.text.substring(
          0,
          b.maxDigits,
        );
      }
    });
  }

  Future<void> _openBankPicker() async {
    final chosen = await showBankPickerSheet(
      context,
      currentBank: _selectedBank,
    );
    if (chosen != null) {
      _onBankSelected(chosen);
    }
  }

  Future<void> _save() async {
    if (_busy || _saving || _hasLinkedBank || !_formKey.currentState!.validate()) return;

    // Hiện hộp thoại cảnh báo: Chỉ được thêm 1 ngân hàng và không thể sửa đổi
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lock_person_rounded,
                color: Color(0xFFD97706),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Xác nhận liên kết ngân hàng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bạn đang liên kết tài khoản ngân hàng để nhận thu nhập từ TaskLy:',
              style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildConfirmRow('Ngân hàng:', _selectedBank.displayName),
                  const SizedBox(height: 6),
                  _buildConfirmRow(
                    'Số tài khoản:',
                    _accountController.text.trim(),
                  ),
                  const SizedBox(height: 6),
                  _buildConfirmRow(
                    'Chủ tài khoản:',
                    _ownerController.text.trim().toUpperCase(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
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
                    Icons.warning_amber_rounded,
                    color: Color(0xFFB45309),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'LƯU Ý QUAN TRỌNG: Mỗi Đối tác chỉ được thêm DUY NHẤT 1 ngân hàng và KHÔNG THỂ thay đổi hoặc thêm tài khoản thứ 2 sau khi lưu. Vui lòng kiểm tra thật chính xác!',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Kiểm tra lại',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đồng ý & Khóa liên kết'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final saved = await widget.session.request(
        '/partner/bank-account',
        method: 'PUT',
        body: {
          'bankName': _selectedBank.displayName,
          'accountName': _ownerController.text.trim().toUpperCase(),
          'accountNumber': _accountController.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _hasLinkedBank = true;
        _bankController.text = saved['bankName'].toString();
        _ownerController.text = saved['accountName'].toString();
        _accountController.text = saved['accountNumber'].toString();
        _selectedBank = findVietnameseBank(_bankController.text);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Liên kết ngân hàng thành công! Tài khoản đã được khóa bảo mật.',
          ),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ApiFailure ? e.message : 'Không thể lưu ngân hàng.';
        });
      }
    }
  }

  Widget _buildConfirmRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  void _showSupportSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Hỗ trợ thay đổi tài khoản ngân hàng',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Vì lý do bảo mật tài chính, mỗi Đối tác chỉ liên kết duy nhất 01 ngân hàng. Nếu bạn cần đổi số tài khoản do khóa thẻ hoặc đổi ngân hàng, vui lòng chuẩn bị ảnh chụp CCCD/CMND chính chủ và liên hệ CSKH:',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.phone_in_talk_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
                title: const Text(
                  'Tổng đài Đối tác: 1900 6868',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Hỗ trợ 24/7 (Bấm để sao chép)',
                  style: TextStyle(fontSize: 11.5),
                ),
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: '19006868'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép số tổng đài')),
                  );
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF16A34A),
                  ),
                ),
                title: const Text(
                  'Email: hotro@taskly.vn',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: const Text(
                  'Tiêu đề: [Đổi STK] + Mã đối tác',
                  style: TextStyle(fontSize: 11.5),
                ),
                onTap: () {
                  Clipboard.setData(
                    const ClipboardData(text: 'hotro@taskly.vn'),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép email hỗ trợ')),
                  );
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _hasLinkedBank
              ? 'Tài khoản ngân hàng Đối tác'
              : 'Thêm tài khoản ngân hàng',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error ?? 'Không thể tải thông tin ngân hàng.'),
              TextButton(onPressed: _load, child: const Text('Thử lại')),
            ]))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: _hasLinkedBank ? _buildLockedView() : _buildAddForm(),
            ),
    );
  }

  /// GIAO DIỆN KHI ĐÃ CÓ 1 NGÂN HÀNG (ĐÃ KHÓA BẢO MẬT, KHÔNG ĐƯỢC THAY ĐỔI / THÊM TÀI KHOẢN THỨ 2)
  Widget _buildLockedView() {
    final accountNumber = _accountController.text.trim();
    final ownerName = _ownerController.text.trim();
    final brandColor = _selectedBank.brandColor;

    final formattedNumber = accountNumber.isNotEmpty
        ? accountNumber
              .replaceAllMapped(
                RegExp(r".{4}"),
                (match) => "${match.group(0)} ",
              )
              .trim()
        : '•••• •••• •••• ••••';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ATM Card Preview (Locked state)
        _buildAtmCardPreview(
          brandColor: brandColor,
          bank: _selectedBank,
          formattedNumber: formattedNumber,
          owner: ownerName,
          isLocked: true,
        ),
        const SizedBox(height: 16),

        // Verified Status Badge
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF16A34A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tài khoản nhận thu nhập chính thức',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF166534),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Thu nhập nhận việc & thưởng sẽ tự động chuyển về đây.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Bank Details Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    size: 18,
                    color: Color(0xFF0F172A),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Chi tiết tài khoản nhận tiền',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),

              // Bank Name Row
              _buildDetailItem(
                label: 'Ngân hàng',
                value: '${_selectedBank.shortName} - ${_selectedBank.fullName}',
                badge: _selectedBank.shortName,
                badgeColor: _selectedBank.brandColor,
              ),
              const SizedBox(height: 12),

              // Account Number Row with Copy
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 105,
                    child: Text(
                      'Số tài khoản',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          accountNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: Color(0xFF0F172A),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: accountNumber),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép số tài khoản'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 15,
                              color: Color(0xFF0F9D7A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Cardholder Name Row
              _buildDetailItem(
                label: 'Chủ tài khoản',
                value: ownerName.toUpperCase(),
              ),
              const SizedBox(height: 12),

              // Status Row
              Row(
                children: [
                  const SizedBox(
                    width: 105,
                    child: Text(
                      'Trạng thái',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 11,
                          color: Color(0xFF16A34A),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Đã kích hoạt & Cố định duy nhất',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Policy Notice: Strictly 1 Bank & Locked
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Chính sách cố định 01 tài khoản Đối tác:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '• Để bảo vệ an toàn tài chính và phòng chống gian lận rút tiền, mỗi Đối tác chỉ được liên kết duy nhất 01 tài khoản ngân hàng và KHÔNG THỂ thay đổi hoặc thêm tài khoản thứ 2 trên ứng dụng.\n• Trường hợp bất khả kháng (đổi số tài khoản, mất thẻ), Đối tác vui lòng liên hệ Bộ phận Hỗ trợ Đối tác (CSKH) cùng giấy tờ tùy thân CCCD/CMND để được hướng dẫn xác thực.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF78350F),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showSupportSheet,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD97706)),
                    foregroundColor: const Color(0xFFB45309),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.support_agent_rounded, size: 18),
                  label: const Text(
                    'Liên hệ CSKH để hỗ trợ đổi tài khoản',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Security Footnote
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 14, color: Color(0xFF94A3B8)),
            SizedBox(width: 6),
            Text(
              'Tài khoản được bảo vệ bởi tiêu chuẩn mã hóa dữ liệu TaskLy',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailItem({
    required String label,
    required String value,
    String? badge,
    Color? badgeColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              if (badge != null && badgeColor != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: badgeColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// GIAO DIỆN KHI CHƯA CÓ NGÂN HÀNG (GIỐNG CUSTOMER NHƯNG CÓ CẢNH BÁO DUY NHẤT 1 TÀI KHOẢN)
  Widget _buildAddForm() {
    final accountNumber = _accountController.text.trim();
    final ownerName = _ownerController.text.trim();
    final brandColor = _selectedBank.brandColor;
    final popularBanks = kVietnameseBanks.where((b) => b.isPopular).toList();

    final formattedNumber = accountNumber.isNotEmpty
        ? accountNumber
              .replaceAllMapped(
                RegExp(r".{4}"),
                (match) => "${match.group(0)} ",
              )
              .trim()
        : '•••• •••• •••• ••••';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Notice banner: 1 bank only & locked
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFB45309),
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LƯU Ý QUAN TRỌNG CHO ĐỐI TÁC:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Bạn chỉ được liên kết DUY NHẤT 01 ngân hàng nhận thu nhập và KHÔNG THỂ thay đổi sau khi xác nhận. Vui lòng kiểm tra kỹ số tài khoản và họ tên chính chủ.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF78350F),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ATM Card Live Preview (Matching Customer UI)
          _buildAtmCardPreview(
            brandColor: brandColor,
            bank: _selectedBank,
            formattedNumber: formattedNumber,
            owner: ownerName,
            isLocked: false,
          ),
          const SizedBox(height: 16),

          // Quick Bank Selection (Chips)
          const Text(
            'Ngân hàng phổ biến:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: popularBanks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final b = popularBanks[index];
                final isSelected = _selectedBank.code == b.code;
                return InkWell(
                  onTap: () => _onBankSelected(b),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.mint
                          : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        b.shortName,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Bank Selector (Scrollable & Searchable Modal, strictly no manual text typing)
          InkWell(
            onTap: _openBankPicker,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _selectedBank.brandColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedBank.brandColor.withOpacity(0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _selectedBank.shortName.length > 5
                          ? _selectedBank.shortName.substring(0, 5)
                          : _selectedBank.shortName,
                      style: TextStyle(
                        color: _selectedBank.brandColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ngân hàng thụ hưởng *',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_selectedBank.shortName} - ${_selectedBank.fullName}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Độ dài STK chuẩn: ${_selectedBank.digitsRule}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _selectedBank.brandColor,
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
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          'Đổi',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Account Number Field with Bank Length Limits
          TextFormField(
            controller: _accountController,
            keyboardType: TextInputType.number,
            maxLength: _selectedBank.maxDigits,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_selectedBank.maxDigits),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Số tài khoản *',
              hintText: 'Ví dụ: 0123456789',
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              helperText:
                  '${_selectedBank.shortName} quy định ${_selectedBank.digitsRule} (${_accountController.text.length}/${_selectedBank.maxDigits} số)',
              prefixIcon: const Icon(Icons.credit_card_rounded, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            validator: (v) {
              final clean = v?.trim() ?? '';
              if (clean.isEmpty) {
                return 'Vui lòng nhập số tài khoản';
              }
              if (clean.length < _selectedBank.minDigits ||
                  clean.length > _selectedBank.maxDigits) {
                return 'STK ${_selectedBank.shortName} phải có ${_selectedBank.digitsRule} (hiện có ${clean.length} số)';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Account Holder Field
          TextFormField(
            controller: _ownerController,
            readOnly: true,
            enableInteractiveSelection: false,
            decoration: InputDecoration(
              labelText: 'Tên chủ tài khoản *',
              hintText: 'Họ tên trong hồ sơ Partner',
              helperText: 'Tự động lấy từ hồ sơ Partner, không thể chỉnh sửa',
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            validator: (v) => (v?.trim().isEmpty ?? true)
                ? 'Hồ sơ Partner chưa có họ tên. Vui lòng kiểm tra hồ sơ.'
                : null,
          ),
          const SizedBox(height: 14),

          // Security Notice Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bảo mật an toàn: TaskLy chỉ lưu số tài khoản để chuyển thu nhập cho Đối tác. Tuyệt đối KHÔNG yêu cầu mã PIN, mật khẩu ngân hàng hoặc mã OTP.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF166534),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Submit Button
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _saving
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
                      Text(
                        'Đang lưu & Khóa tài khoản...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Xác nhận & Khóa liên kết ngân hàng',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// ATM Card Component (Dùng chung cho cả 2 trạng thái)
  Widget _buildAtmCardPreview({
    required Color brandColor,
    required VietnameseBank bank,
    required String formattedNumber,
    required String owner,
    required bool isLocked,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            brandColor,
            brandColor.withOpacity(0.85),
            Color.alphaBlend(Colors.black.withOpacity(0.35), brandColor),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: brandColor.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      bank.shortName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    bank.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.contactless_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 30,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFFD97706)),
                ),
                child: const Center(
                  child: Icon(Icons.memory, size: 14, color: Color(0xFF78350F)),
                ),
              ),
              if (isLocked)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'ĐÃ KHÓA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formattedNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CHỦ TÀI KHOẢN',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      owner.isNotEmpty ? owner.toUpperCase() : 'HO VA TEN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Text(
                'TASKLY PAYOUT',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
