import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Danh mục chuẩn các ngân hàng tại Việt Nam (hỗ trợ VietQR / Napas).
/// Quy định giới hạn độ dài số tài khoản chuẩn cho từng ngân hàng.
class VietnameseBank {
  final String shortName;
  final String code;
  final String fullName;
  final int minDigits;
  final int maxDigits;
  final Color brandColor;
  final bool isPopular;

  const VietnameseBank({
    required this.shortName,
    required this.code,
    required this.fullName,
    required this.minDigits,
    required this.maxDigits,
    required this.brandColor,
    this.isPopular = false,
  });

  String get displayName => '$shortName ($code)';
  String get digitsRule =>
      minDigits == maxDigits ? '$minDigits chữ số' : '$minDigits - $maxDigits chữ số';
}

const List<VietnameseBank> kVietnameseBanks = [
  VietnameseBank(
    shortName: 'Vietcombank',
    code: 'VCB',
    fullName: 'TMCP Ngoại thương Việt Nam',
    minDigits: 10,
    maxDigits: 13,
    brandColor: Color(0xFF00733B),
    isPopular: true,
  ),
  VietnameseBank(
    shortName: 'MB Bank',
    code: 'MB',
    fullName: 'TMCP Quân đội',
    minDigits: 9,
    maxDigits: 13,
    brandColor: Color(0xFF142C8E),
    isPopular: true,
  ),
  VietnameseBank(
    shortName: 'Techcombank',
    code: 'TCB',
    fullName: 'TMCP Kỹ thương Việt Nam',
    minDigits: 10,
    maxDigits: 14,
    brandColor: Color(0xFFE51A24),
    isPopular: true,
  ),
  VietnameseBank(
    shortName: 'ACB',
    code: 'ACB',
    fullName: 'TMCP Á Châu',
    minDigits: 8,
    maxDigits: 9,
    brandColor: Color(0xFF005BAC),
    isPopular: true,
  ),
  VietnameseBank(
    shortName: 'BIDV',
    code: 'BIDV',
    fullName: 'TMCP Đầu tư & Phát triển Việt Nam',
    minDigits: 10,
    maxDigits: 14,
    brandColor: Color(0xFF1B6B53),
    isPopular: true,
  ),
  VietnameseBank(
    shortName: 'VietinBank',
    code: 'CTG',
    fullName: 'TMCP Công thương Việt Nam',
    minDigits: 12,
    maxDigits: 12,
    brandColor: Color(0xFF005696),
    isPopular: true,
  ),
  VietnameseBank(
    shortName: 'Agribank',
    code: 'VBA',
    fullName: 'Nông nghiệp & Phát triển Nông thôn Việt Nam',
    minDigits: 13,
    maxDigits: 13,
    brandColor: Color(0xFF8B181B),
    isPopular: true,
  ),
  VietnameseBank(
    shortName: 'VPBank',
    code: 'VPB',
    fullName: 'TMCP Việt Nam Thịnh Vượng',
    minDigits: 8,
    maxDigits: 10,
    brandColor: Color(0xFF008D44),
    isPopular: true,
  ),
  VietnameseBank(
    shortName: 'TPBank',
    code: 'TPB',
    fullName: 'TMCP Tiên Phong',
    minDigits: 10,
    maxDigits: 12,
    brandColor: Color(0xFF7A2082),
    isPopular: true,
  ),
  VietnameseBank(
    shortName: 'Sacombank',
    code: 'STB',
    fullName: 'TMCP Sài Gòn Thương Tín',
    minDigits: 10,
    maxDigits: 12,
    brandColor: Color(0xFF00529C),
    isPopular: true,
  ),
  VietnameseBank(
    shortName: 'HDBank',
    code: 'HDB',
    fullName: 'TMCP Phát triển TP. Hồ Chí Minh',
    minDigits: 12,
    maxDigits: 15,
    brandColor: Color(0xFFD6181F),
    isPopular: true,
  ),
  VietnameseBank(
    shortName: 'VIB',
    code: 'VIB',
    fullName: 'TMCP Quốc tế Việt Nam',
    minDigits: 9,
    maxDigits: 15,
    brandColor: Color(0xFF004990),
    isPopular: true,
  ),
  VietnameseBank(
    shortName: 'SHB',
    code: 'SHB',
    fullName: 'TMCP Sài Gòn - Hà Nội',
    minDigits: 10,
    maxDigits: 10,
    brandColor: Color(0xFFFF6600),
  ),
  VietnameseBank(
    shortName: 'MSB',
    code: 'MSB',
    fullName: 'TMCP Hàng Hải Việt Nam',
    minDigits: 10,
    maxDigits: 12,
    brandColor: Color(0xFFE84E1B),
  ),
  VietnameseBank(
    shortName: 'SeABank',
    code: 'SEAB',
    fullName: 'TMCP Đông Nam Á',
    minDigits: 12,
    maxDigits: 16,
    brandColor: Color(0xFFBA0C2F),
  ),
  VietnameseBank(
    shortName: 'OCB',
    code: 'OCB',
    fullName: 'TMCP Phương Đông',
    minDigits: 10,
    maxDigits: 14,
    brandColor: Color(0xFF00693E),
  ),
  VietnameseBank(
    shortName: 'LPBank',
    code: 'LPB',
    fullName: 'TMCP Lộc Phát Việt Nam',
    minDigits: 10,
    maxDigits: 12,
    brandColor: Color(0xFFE35205),
  ),
  VietnameseBank(
    shortName: 'Eximbank',
    code: 'EIB',
    fullName: 'TMCP Xuất Nhập khẩu Việt Nam',
    minDigits: 15,
    maxDigits: 15,
    brandColor: Color(0xFF0072CE),
  ),
  VietnameseBank(
    shortName: 'Nam A Bank',
    code: 'NAB',
    fullName: 'TMCP Nam Á',
    minDigits: 10,
    maxDigits: 14,
    brandColor: Color(0xFFEBB700),
  ),
  VietnameseBank(
    shortName: 'Bac A Bank',
    code: 'BAB',
    fullName: 'TMCP Bắc Á',
    minDigits: 12,
    maxDigits: 14,
    brandColor: Color(0xFFB78732),
  ),
  VietnameseBank(
    shortName: 'ABBank',
    code: 'ABB',
    fullName: 'TMCP An Bình',
    minDigits: 10,
    maxDigits: 12,
    brandColor: Color(0xFF009688),
  ),
  VietnameseBank(
    shortName: 'BVBank',
    code: 'BVB',
    fullName: 'TMCP Bản Việt',
    minDigits: 10,
    maxDigits: 15,
    brandColor: Color(0xFF005BA6),
  ),
  VietnameseBank(
    shortName: 'PVcomBank',
    code: 'PVCB',
    fullName: 'TMCP Đại Chúng Việt Nam',
    minDigits: 10,
    maxDigits: 12,
    brandColor: Color(0xFF0054A6),
  ),
  VietnameseBank(
    shortName: 'BaoViet Bank',
    code: 'BVBANK',
    fullName: 'TMCP Bảo Việt',
    minDigits: 10,
    maxDigits: 14,
    brandColor: Color(0xFF0070BA),
  ),
  VietnameseBank(
    shortName: 'Shinhan Bank',
    code: 'SHBVN',
    fullName: 'TNHH MTV Shinhan Việt Nam',
    minDigits: 9,
    maxDigits: 12,
    brandColor: Color(0xFF004687),
  ),
  VietnameseBank(
    shortName: 'KienlongBank',
    code: 'KLB',
    fullName: 'TMCP Kiên Long',
    minDigits: 10,
    maxDigits: 13,
    brandColor: Color(0xFF00833E),
  ),
  VietnameseBank(
    shortName: 'Saigonbank',
    code: 'SGB',
    fullName: 'TMCP Sài Gòn Công Thương',
    minDigits: 10,
    maxDigits: 14,
    brandColor: Color(0xFF0054A4),
  ),
  VietnameseBank(
    shortName: 'Cake by VPBank',
    code: 'CAKE',
    fullName: 'Ngân hàng số Cake by VPBank',
    minDigits: 10,
    maxDigits: 10,
    brandColor: Color(0xFFE91E63),
  ),
  VietnameseBank(
    shortName: 'Timo',
    code: 'TIMO',
    fullName: 'Ngân hàng số Timo by BVBank',
    minDigits: 9,
    maxDigits: 12,
    brandColor: Color(0xFF6B3BA6),
  ),
  VietnameseBank(
    shortName: 'Viettel Money',
    code: 'VTLMONEY',
    fullName: 'Tổng Công ty Dịch vụ số Viettel',
    minDigits: 10,
    maxDigits: 12,
    brandColor: Color(0xFFE60000),
  ),
];

VietnameseBank findVietnameseBank(String? nameOrCode) {
  if (nameOrCode == null || nameOrCode.trim().isEmpty) {
    return kVietnameseBanks.first;
  }
  final clean = nameOrCode.trim().toLowerCase();
  for (final b in kVietnameseBanks) {
    if (clean == b.shortName.toLowerCase() ||
        clean == b.code.toLowerCase() ||
        clean == b.displayName.toLowerCase() ||
        clean.contains(b.code.toLowerCase()) ||
        clean.contains(b.shortName.toLowerCase())) {
      return b;
    }
  }
  return kVietnameseBanks.first;
}

Future<VietnameseBank?> showBankPickerSheet(
  BuildContext context, {
  VietnameseBank? currentBank,
}) async {
  return showModalBottomSheet<VietnameseBank>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => BankPickerSheet(currentBank: currentBank),
  );
}

class BankPickerSheet extends StatefulWidget {
  const BankPickerSheet({super.key, this.currentBank});

  final VietnameseBank? currentBank;

  @override
  State<BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<BankPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredBanks = kVietnameseBanks.where((b) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return b.shortName.toLowerCase().contains(q) ||
          b.code.toLowerCase().contains(q) ||
          b.fullName.toLowerCase().contains(q);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chọn ngân hàng thụ hưởng',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hơn 30 ngân hàng chính thống tại Việt Nam',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, mã (VCB, MB, ACB, Sacombank...)',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
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
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // List
          Flexible(
            child: filteredBanks.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                        SizedBox(height: 8),
                        Text(
                          'Không tìm thấy ngân hàng phù hợp',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredBanks.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 68, color: Color(0xFFF8FAFC)),
                    itemBuilder: (context, index) {
                      final b = filteredBanks[index];
                      final isSelected = widget.currentBank != null &&
                          b.code == widget.currentBank!.code;
                      return InkWell(
                        onTap: () => Navigator.pop(context, b),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: isSelected ? const Color(0xFFF0FDF4) : Colors.transparent,
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: b.brandColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  b.code,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
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
                                          b.shortName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? AppColors.primary
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            b.code,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                        if (b.isPopular) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Phổ biến',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF166534),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      b.fullName,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Icon(Icons.pin_outlined,
                                            size: 12, color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Độ dài STK: ${b.digitsRule}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F766E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
