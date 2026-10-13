import 'package:flutter/material.dart';
import 'dart:convert';

import '../../auth/api.dart';
import 'partner_ui_kit.dart';

class RecruitmentUniform extends StatefulWidget {
  const RecruitmentUniform({super.key, required this.session, this.ordersOnly = false});
  final Session session;
  final bool ordersOnly;

  @override
  State<RecruitmentUniform> createState() => _RecruitmentUniformState();
}

class _RecruitmentUniformState extends State<RecruitmentUniform> {
  Map<String, dynamic>? application;
  List<dynamic> packages = [];
  List<dynamic> orders = [];
  List<dynamic> get activeOrders => orders.where((order) => !['CANCELLED', 'REFUNDED'].contains(order['status'])).toList();
  String? packageId;
  String? size;
  String payment = 'AT_OFFICE';
  bool busy = false;
  String? error;
  late bool ordersOnly = widget.ordersOnly;


  @override
  void initState() {
    super.initState();
    load();
  }

  bool _isUniformPackage(Map<String, dynamic> p) {
    final packageType = (p['packageType'] ?? '').toString().toUpperCase();
    if (packageType == 'ITEM' || packageType == 'LE') return false;
    final policy = (p['policy'] ?? '').toString();
    if (policy.contains('[TYPE:ITEM]') || policy.contains('[LOAI:LE]')) return false;
    final desc = (p['description'] ?? '').toString();
    if (desc.contains('[TYPE:ITEM]') || desc.contains('[LOAI:LE]')) return false;
    final items = p['items'];
    if (items is List) {
      for (final it in items) {
        if (it is Map && (it['type'] == 'ITEM' || it['packageType'] == 'ITEM')) {
          return false;
        }
      }
    }
    return true;
  }

  String _cleanPolicy(String raw) {
    return raw
        .replaceAll(RegExp(r'\[TYPE:(ITEM|PACKAGE)\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[LOAI:(LE|GOI)\]', caseSensitive: false), '')
        .trim();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final appRes = await widget.session
          .request('/partner/onboarding')
          .catchError((_) => <String, dynamic>{'status': 'REGISTERED'});
      final uniformsRes = await widget.session
          .request('/partner/uniforms')
          .catchError((_) => <dynamic>[]);
      final ordersRes = await widget.session
          .request('/partner/uniform-orders')
          .catchError((_) => <dynamic>[]);

      if (!mounted) return;
      setState(() {
        application = Map<String, dynamic>.from(
          appRes is Map ? appRes : {'status': 'REGISTERED'},
        );
        packages = uniformsRes is List
            ? uniformsRes
                .where((p) => p['active'] != false && _isUniformPackage(Map<String, dynamic>.from(p)))
                .toList()
            : [];
        orders = ordersRes is List ? ordersRes : [];
        if (!packages.any((p) => p['id'] == packageId && ((p['sizes'] as Map?) ?? {}).values.any((v) => (int.tryParse(v.toString()) ?? 0) > 0))) {
          packageId = packages.isNotEmpty ? packages.first['id']?.toString() : null;
          size = null;
        }
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> action(String path, {Map<String, dynamic>? body}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.request(path, method: 'POST', body: body);
      if (path == '/partner/uniform-orders') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đặt đồng phục thành công. Tiếp tục xem địa chỉ văn phòng.')));
        Navigator.of(context).pop();
        return;
      }
      await load();
      if (path.endsWith('/cancel') && mounted && !orders.any((order) => !['CANCELLED', 'REFUNDED'].contains(order['status']))) {
        setState(() { ordersOnly = false; packageId = null; size = null; });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Đã cập nhật đơn đồng phục thành công!')),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showSizeGuideSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.straighten_rounded,
                    color: PartnerColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Bảng thông số kích thước áo',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSizeRow('Size S', '1m50 - 1m60', '45 - 53 kg'),
            _buildSizeRow('Size M', '1m60 - 1m68', '54 - 63 kg'),
            _buildSizeRow('Size L', '1m68 - 1m75', '64 - 72 kg'),
            _buildSizeRow('Size XL', '1m75 - 1m82', '73 - 82 kg'),
            _buildSizeRow('Size XXL', 'Trên 1m80', 'Trên 82 kg'),
            const SizedBox(height: 16),
            const Text(
              '* Áo polo có độ co giãn tốt, form chuẩn châu Á. Nếu phân vân giữa 2 kích cỡ, đối tác nên chọn kích cỡ lớn hơn để thoải mái thao tác.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: PartnerColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Đã hiểu'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeRow(String sizeName, String height, String weight) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            sizeName,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            height,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          Text(
            weight,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PartnerColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? selected;
    for (final p in packages) {
      if (p['id'] == packageId) selected = Map<String, dynamic>.from(p);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Đồng phục & Trang bị',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.straighten_rounded,
              color: Color(0xFF475569),
            ),
            tooltip: 'Bảng kích cỡ',
            onPressed: _showSizeGuideSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (busy)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    color: PartnerColors.primary,
                    backgroundColor: Color(0xFFDBEAFE),
                  ),
                ),
              ),

            if (error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
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
                          color: Color(0xFFB91C1C),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Hero Banner
            if (!ordersOnly) _buildHeroBanner(),

            const SizedBox(height: 12),

            // Orders list if already created
            if (activeOrders.isNotEmpty) ...[
              _buildOrdersSection(),
              const SizedBox(height: 14),
            ],
            if (ordersOnly && activeOrders.isEmpty && !busy) const Text('Chưa có đơn đồng phục.'),

            // Section 1: Package selection
            if (!ordersOnly) ...[
            _buildPackageSection(selected),
            ...packages.where((p) => (p['imageUrl'] ?? '').toString().isNotEmpty || (p['items'] as List? ?? []).isNotEmpty).map((p) => _buildPackageImages(Map<String, dynamic>.from(p))),

            const SizedBox(height: 16),

            // Section 2: Size selection
            if (selected != null) _buildSizeSection(selected),

            const SizedBox(height: 16),

            // Section 3: Payment method
            _buildPaymentSection(),

            const SizedBox(height: 24),

            // Order submit button
            _buildSubmitButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      padding: EdgeInsets.all(orders.isNotEmpty ? 14 : 20),
      decoration: BoxDecoration(
        gradient: PartnerColors.luxuryBlueGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x181E40AF),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.checkroom_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đồng phục chính hãng TaskLy',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Trang bị nhận diện chuyên nghiệp chuẩn 5 sao',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDBEAFE),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: orders.isNotEmpty ? 10 : 16),
          const Text(
            'Giá và chính sách do Admin cấu hình. Gói đắt hơn không được ưu tiên việc.',
            style: TextStyle(fontSize: 12.5, color: Colors.white, height: 1.35),
          ),
          SizedBox(height: orders.isNotEmpty ? 8 : 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.store_rounded, color: Colors.white, size: 15),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Được cấp phát và bàn giao khi đến văn phòng đối chiếu bản gốc CCCD.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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

  String _formatVnd(dynamic amount) {
    final numVal = int.tryParse(amount?.toString() ?? '') ?? 0;
    if (numVal == 0) return '0 đ';
    final s = numVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(s[i]);
    }
    return '${buffer.toString()} đ';
  }

  Widget _buildOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.inventory_2_rounded,
              color: PartnerColors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Đơn đồng phục đã đăng ký',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                '${orders.length} đơn',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...activeOrders.map((o) {
          final isPaid = ['PAID', 'WAIVED'].contains(o['payment_status']);
          final isPendingOnline =
              o['payment_method'] == 'ONLINE' &&
              ['PENDING', 'FAILED'].contains(o['payment_status']);
          final canCancel = o['status'] == 'RESERVED' && !isPaid;

          // Find package details
          Map<String, dynamic>? pkg;
          if (o['package_id'] != null) {
            pkg = packages.cast<Map<String, dynamic>?>().firstWhere(
              (p) => p?['id']?.toString() == o['package_id']?.toString(),
              orElse: () => null,
            );
          }
          pkg ??= packages.isNotEmpty ? packages.first as Map<String, dynamic> : null;

          final packageName = o['package_name']?.toString() ??
              pkg?['name']?.toString() ??
              'Bộ trang bị đối tác tiêu chuẩn';
          final rawDesc = pkg?['description']?.toString() ?? '';
          final packageItems = (pkg?['items'] as List? ?? []);
          final packageDesc = rawDesc.isNotEmpty
              ? rawDesc
              : packageItems
                  .map((e) => e is Map ? (e['name'] ?? e['title'] ?? '').toString() : e.toString())
                  .where((s) => s.isNotEmpty)
                  .join(', ');
          final packagePolicy = _cleanPolicy(pkg?['policy']?.toString() ?? '');

          final rawId = (o['id'] ?? '').toString();
          final shortId = rawId.length > 8 ? rawId.substring(0, 8).toUpperCase() : rawId;

          // Format status badge
          final String statusLabel;
          final Color statusBg;
          final Color statusBorder;
          final Color statusColor;

          if (o['status'] == 'CANCELLED') {
            statusLabel = 'Đã hủy';
            statusBg = const Color(0xFFF1F5F9);
            statusBorder = const Color(0xFFCBD5E1);
            statusColor = const Color(0xFF64748B);
          } else if (isPaid) {
            statusLabel = o['payment_status'] == 'WAIVED' ? 'Được hỗ trợ (0 đ)' : 'Đã thanh toán';
            statusBg = const Color(0xFFECFDF5);
            statusBorder = const Color(0xFFA7F3D0);
            statusColor = const Color(0xFF059669);
          } else if (o['payment_status'] == 'FAILED') {
            statusLabel = 'Thanh toán lỗi';
            statusBg = const Color(0xFFFEF2F2);
            statusBorder = const Color(0xFFFECACA);
            statusColor = const Color(0xFFDC2626);
          } else {
            statusLabel = o['payment_method'] == 'ONLINE'
                ? 'Chờ thanh toán online'
                : 'Chờ thanh toán tại VP';
            statusBg = const Color(0xFFFFFBEB);
            statusBorder = const Color(0xFFFDE68A);
            statusColor = const Color(0xFFD97706);
          }

          final priceText = _formatVnd(o['price']);
          final isOnline = o['payment_method'] == 'ONLINE';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isPaid
                    ? const Color(0xFFA7F3D0)
                    : const Color(0xFFE2E8F0),
                width: isPaid ? 1.5 : 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row (Icon + Name + Code + Badge)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPaid ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
                        ),
                      ),
                      child: Icon(
                        Icons.checkroom_rounded,
                        color: isPaid ? const Color(0xFF059669) : const Color(0xFF2563EB),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  packageName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: statusBorder),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Mã đơn: #$shortId',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Specs Summary Bar (Size, Price, Payment Method)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Size Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.straighten_rounded, size: 13, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              'Size ${o['size'] ?? '--'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Price Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.payments_outlined, size: 13, color: Color(0xFF059669)),
                            const SizedBox(width: 4),
                            Text(
                              priceText,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Method
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          isOnline ? 'Online' : 'Tại văn phòng',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Uniform equipment details & delivery policy
                if (packageDesc.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          packageDesc,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (packagePolicy.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.storefront_outlined, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          packagePolicy,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF1E40AF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Receipt note if available
                if (o['receipt_id'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Biên nhận: ${o['receipt_id']}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],

                // Sandbox online payment buttons
                if (isPendingOnline) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Mô phỏng development/test, không thu tiền thật',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFFD97706),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => action(
                                  '/partner/uniform-orders/${o['id']}/payment',
                                  body: {'result': 'SUCCESS'},
                                ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF059669),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Giả lập thành công'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => action(
                                  '/partner/uniform-orders/${o['id']}/payment',
                                  body: {'result': 'FAILURE'},
                                ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Giả lập thất bại'),
                        ),
                      ),
                    ],
                  ),
                ],

                // Cancel button
                if (canCancel && o['payment_method'] != 'AT_OFFICE') TextButton.icon(
                  onPressed: busy ? null : () => action('/partner/uniform-orders/${o['id']}/cash-payment'),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Chọn thanh toán tiền mặt tại văn phòng'),
                ),
                if (canCancel) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: busy
                          ? null
                          : () => action(
                              '/partner/uniform-orders/${o['id']}/cancel',
                            ),
                      icon: const Icon(Icons.cancel_outlined, size: 14),
                      label: const Text('Hủy đơn chưa thanh toán'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPackageSection(Map<String, dynamic>? selected) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gói đồng phục',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ...packages.map((p) {
            final inStock = ((p['sizes'] as Map?) ?? {}).values.any((v) => (int.tryParse(v.toString()) ?? 0) > 0);
            final isChosen = p['id'] == packageId;
            final priceStr = p['price']?.toString() ?? '0';

            return GestureDetector(
              onTap: busy || !inStock ? null : () => setState(() { packageId = p['id'];
                      size = null;
                    }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isChosen ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isChosen
                        ? PartnerColors.primary
                        : const Color(0xFFE2E8F0),
                    width: isChosen ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isChosen
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isChosen
                          ? PartnerColors.primary
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['name']} • ${p['price']} đ',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (!inStock) const Text('Hết hàng', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                          if (priceStr == '0')
                            const Text(
                              'Được TaskLy hỗ trợ 100% chi phí',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (selected != null) ...[
            const SizedBox(height: 10),
            Text(
              selected['description']?.toString() ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF334155),
                height: 1.4,
              ),
            ),
            if (_cleanPolicy(selected['policy']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _cleanPolicy(selected['policy']?.toString() ?? ''),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPackageImages(Map<String, dynamic> p) {
    Widget photo(String source) {
      try {
        return source.startsWith('data:image/') ? Image.memory(base64Decode(source.split(',').last), height: 150, fit: BoxFit.contain) : Image.network(source, height: 150, fit: BoxFit.contain, errorBuilder: (_, error, stack) => const Icon(Icons.broken_image_outlined));
      } catch (_) { return const Icon(Icons.broken_image_outlined); }
    }
    return Column(children: [
      if ((p['imageUrl'] ?? '').toString().isNotEmpty) photo(p['imageUrl']),
      ...(p['items'] as List? ?? []).map((item) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [if ((item['imageUrl'] ?? '').toString().isNotEmpty) photo(item['imageUrl']), Text(item['name'] ?? '')])))),
    ]);
  }
  Widget _buildSizeSection(Map<String, dynamic> selected) {
    final sizesMap = (selected['sizes'] as Map?) ?? {};

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Kích thước áo (Size)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: _showSizeGuideSheet,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.straighten_rounded,
                        size: 14,
                        color: PartnerColors.primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Bảng size',
                        style: TextStyle(
                          fontSize: 12,
                          color: PartnerColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: sizesMap.entries.map((e) {
              final sKey = e.key.toString();
              final sStock = int.tryParse(e.value.toString()) ?? 0;
              final isChosen = size == sKey;

              return GestureDetector(
                onTap: busy || sStock <= 0 ? null : () => setState(() => size = sKey),
                child: Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isChosen ? PartnerColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isChosen
                          ? PartnerColors.primary
                          : const Color(0xFFCBD5E1),
                      width: isChosen ? 1.8 : 1,
                    ),
                    boxShadow: isChosen
                        ? const [
                            BoxShadow(
                              color: Color(0x241E40AF),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        sKey,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isChosen
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sStock > 0 ? 'còn $sStock' : 'Hết hàng',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isChosen
                              ? Colors.white70
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phương thức thanh toán',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _buildPaymentOption(
            value: 'AT_OFFICE',
            title: 'Thanh toán tại văn phòng',
            subtitle: 'Thanh toán trực tiếp khi đến đối chiếu hồ sơ gốc',
            icon: Icons.store_rounded,
          ),
          const SizedBox(height: 8),
          _buildPaymentOption(
            value: 'ONLINE',
            title: 'Online SANDBOX',
            subtitle: 'Mô phỏng thanh toán trực tuyến (Sandbox)',
            icon: Icons.credit_card_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = payment == value;

    return GestureDetector(
      onTap: busy ? null : () => setState(() => payment = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? PartnerColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? PartnerColors.primary
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 22, color: PartnerColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = !busy && packageId != null && size != null && packages.any((p) => p['id'] == packageId && (int.tryParse(((p['sizes'] as Map? ?? {})[size] ?? 0).toString()) ?? 0) > 0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: canSubmit ? PartnerColors.luxuryBlueGradient : null,
        color: canSubmit ? null : const Color(0xFFCBD5E1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canSubmit
              ? () => action(
                  '/partner/uniform-orders',
                  body: {
                    'packageId': packageId,
                    'size': size,
                    'paymentMethod': payment,
                    'requestId':
                        'uniform-${application?['id']}-${DateTime.now().microsecondsSinceEpoch}',
                  },
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    busy ? 'Đang xử lý...' : 'Xác nhận đặt đồng phục',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
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
