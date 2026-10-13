import 'dart:convert';

import 'package:flutter/material.dart';

import '../../auth/api.dart';
import 'partner_ui_kit.dart';

/// Cửa hàng Đồng phục & Trang thiết bị dành riêng cho Đối tác TaskLy
/// Cho phép mua cả Gói đồng phục (Combo) và Đồ lẻ / Phụ kiện rời
class PartnerUniformShop extends StatefulWidget {
  const PartnerUniformShop({super.key, required this.session});

  final Session session;

  @override
  State<PartnerUniformShop> createState() => _PartnerUniformShopState();
}

class _PartnerUniformShopState extends State<PartnerUniformShop> {
  bool busy = false;
  String? error;
  String? notice;

  List<dynamic> allProducts = [];
  List<dynamic> orders = [];
  String categoryFilter = 'ALL'; // 'ALL' | 'PACKAGE' | 'ITEM'
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  bool _isItem(Map<String, dynamic> p) {
    final packageType = (p['packageType'] ?? '').toString().toUpperCase();
    if (packageType == 'ITEM' || packageType == 'LE') return true;
    final policy = (p['policy'] ?? '').toString();
    if (policy.contains('[TYPE:ITEM]') || policy.contains('[LOAI:LE]'))
      return true;
    final desc = (p['description'] ?? '').toString();
    if (desc.contains('[TYPE:ITEM]') || desc.contains('[LOAI:LE]')) return true;
    final items = p['items'];
    if (items is List) {
      for (final it in items) {
        if (it is Map &&
            (it['type'] == 'ITEM' || it['packageType'] == 'ITEM')) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final uniformsRes = await widget.session.request('/partner/uniforms');
      final ordersRes = await widget.session.request('/partner/uniform-orders');

      if (!mounted) return;
      setState(() {
        allProducts = uniformsRes is List
            ? uniformsRes.where((p) => p['active'] != false).toList()
            : [];
        orders = ordersRes is List ? ordersRes : [];
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<dynamic> get filteredProducts {
    var list = allProducts;
    if (categoryFilter == 'PACKAGE') {
      list = list.where((p) => !_isItem(Map<String, dynamic>.from(p))).toList();
    } else if (categoryFilter == 'ITEM') {
      list = list.where((p) => _isItem(Map<String, dynamic>.from(p))).toList();
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final desc = (p['description'] ?? '').toString().toLowerCase();
        return name.contains(q) || desc.contains(q);
      }).toList();
    }
    return list;
  }

  List<dynamic> get activeOrders => orders
      .where((o) => !['CANCELLED', 'REFUNDED'].contains(o['status']))
      .toList();

  String _formatVnd(dynamic amount) {
    final val = int.tryParse(amount?.toString() ?? '0') ?? 0;
    if (val == 0) return 'Miễn phí';
    final str = val.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return '${buffer.toString()} đ';
  }

  String _cleanPolicy(String raw) {
    return raw
        .replaceAll(
          RegExp(r'\[TYPE:(ITEM|PACKAGE)\]', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\[LOAI:(LE|GOI)\]', caseSensitive: false), '')
        .trim();
  }

  static Widget _renderProductImage(
    String imageUrl, {
    required double size,
    required bool isItem,
    BoxFit fit = BoxFit.cover,
  }) {
    if (imageUrl.isEmpty) {
      return Text(
        isItem ? '👕' : '📦',
        style: TextStyle(fontSize: size * 0.44),
      );
    }

    try {
      if (imageUrl.startsWith('data:image/')) {
        final commaIdx = imageUrl.indexOf(',');
        final base64Str = commaIdx != -1
            ? imageUrl.substring(commaIdx + 1)
            : imageUrl;
        final bytes = base64Decode(base64Str.trim());
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (_, __, ___) => Text(
            isItem ? '👕' : '📦',
            style: TextStyle(fontSize: size * 0.44),
          ),
        );
      } else {
        return Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (_, __, ___) => Text(
            isItem ? '👕' : '📦',
            style: TextStyle(fontSize: size * 0.44),
          ),
        );
      }
    } catch (_) {
      return Text(
        isItem ? '👕' : '📦',
        style: TextStyle(fontSize: size * 0.44),
      );
    }
  }

  void _showEnlargedImage(
    BuildContext context,
    Map<String, dynamic> product, {
    required String Function(dynamic) formatVnd,
    required bool isItem,
  }) {
    final imageUrl = (product['imageUrl'] ?? '').toString();
    if (imageUrl.isEmpty) return;

    final name = (product['name'] ?? 'Hình ảnh sản phẩm').toString();
    final price = product['price'];

    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        Widget imageContent;
        try {
          if (imageUrl.startsWith('data:image/')) {
            final commaIdx = imageUrl.indexOf(',');
            final base64Str = commaIdx != -1
                ? imageUrl.substring(commaIdx + 1)
                : imageUrl;
            final bytes = base64Decode(base64Str.trim());
            imageContent = Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  size: 64,
                  color: Colors.white70,
                ),
              ),
            );
          } else {
            imageContent = Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  size: 64,
                  color: Colors.white70,
                ),
              ),
            );
          }
        } catch (_) {
          imageContent = const Center(
            child: Icon(
              Icons.broken_image_rounded,
              size: 64,
              color: Colors.white70,
            ),
          );
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: isItem
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isItem ? 'ĐỒ LẺ' : 'GÓI COMBO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (price != null)
                            Text(
                              formatVnd(price),
                              style: const TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),

              // Zoomable Interactive View
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.65,
                    minWidth: double.infinity,
                  ),
                  color: Colors.black,
                  child: ClipRect(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.5,
                      clipBehavior: Clip.hardEdge,
                      child: Center(child: imageContent),
                    ),
                  ),
                ),
              ),

              // Footer Bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pinch_rounded, color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Chụm 2 ngón tay hoặc vuốt để thu phóng',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPurchaseSheet(Map<String, dynamic> product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PurchaseModal(
        product: product,
        session: widget.session,
        isItem: _isItem(product),
        formatVnd: _formatVnd,
        cleanPolicy: _cleanPolicy,
        onEnlargeImage: (item) => _showEnlargedImage(
          context,
          item,
          formatVnd: _formatVnd,
          isItem: _isItem(item),
        ),
        onSuccess: () async {
          await load();
          if (!mounted) return;
          _openOrderHistorySheet();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đặt trang bị thành công! Bạn có thể xem lại tại Lịch sử đơn hàng.',
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _openOrderHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OrderHistoryModal(
        orders: orders,
        session: widget.session,
        formatVnd: _formatVnd,
        onReload: load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final packageCount = allProducts
        .where((p) => !_isItem(Map<String, dynamic>.from(p)))
        .length;
    final itemCount = allProducts
        .where((p) => _isItem(Map<String, dynamic>.from(p)))
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: PartnerColors.navy,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cửa hàng Trang bị TaskLy',
              style: TextStyle(
                color: PartnerColors.navy,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Đồng phục chính hãng & Đồ nghề tác nghiệp',
              style: TextStyle(
                color: PartnerColors.muted.withValues(alpha: 0.9),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Đơn hàng của tôi',
                icon: const Icon(
                  Icons.shopping_bag_outlined,
                  color: PartnerColors.navy,
                  size: 24,
                ),
                onPressed: _openOrderHistorySheet,
              ),
              if (activeOrders.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${activeOrders.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: busy && allProducts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BANNER PROMO
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A1E3A8A),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8)
                                      .withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF38BDF8)
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Text(
                                  '✨ TRANG BỊ CHÍNH HÃNG',
                                  style: TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _openOrderHistorySheet,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                label: const Text(
                                  'Đơn của tôi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Mua trọn gói hoặc mua lẻ vật phẩm',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Trang phục polo thoáng khí, nón bảo hiểm chuẩn an toàn, túi đồ nghề TaskLy. Nhận tại TaskLy Hub hoặc thanh toán online.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // SEARCH BOX
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => searchQuery = val),
                        decoration: InputDecoration(
                          hintText:
                              'Tìm kiếm gói hoặc món lẻ (áo, nón, túi...)...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      setState(() => searchQuery = ''),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // CATEGORY FILTER TABS
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterTab(
                            id: 'ALL',
                            title: 'Tất cả (${allProducts.length})',
                            icon: Icons.grid_view_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterTab(
                            id: 'PACKAGE',
                            title: '📦 Gói đồng phục ($packageCount)',
                            icon: Icons.inventory_2_outlined,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterTab(
                            id: 'ITEM',
                            title: '👕 Đồ lẻ & Phụ kiện ($itemCount)',
                            icon: Icons.checkroom_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],

                    // PRODUCTS LIST
                    if (filteredProducts.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(40),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Không tìm thấy sản phẩm phù hợp',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              searchQuery.isNotEmpty
                                  ? 'Thử tìm với từ khóa khác.'
                                  : 'Danh mục hiện tại đang được cập nhật.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredProducts.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 14),
                        itemBuilder: (ctx, idx) {
                          final product = Map<String, dynamic>.from(
                            filteredProducts[idx],
                          );
                          final isItem = _isItem(product);
                          final sizes = (product['sizes'] as Map?) ?? {};
                          final totalStock = sizes.values.fold<int>(
                            0,
                            (sum, v) => sum + (int.tryParse(v.toString()) ?? 0),
                          );
                          final isOutOfStock = totalStock <= 0;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x060F172A),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // TOP ROW: BADGE & PRICE
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    14,
                                    16,
                                    10,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Image or Icon with zoom tap
                                      GestureDetector(
                                        onTap:
                                            (product['imageUrl'] ?? '')
                                                .toString()
                                                .isNotEmpty
                                            ? () => _showEnlargedImage(
                                                context,
                                                product,
                                                formatVnd: _formatVnd,
                                                isItem: isItem,
                                              )
                                            : null,
                                        child: Container(
                                          width: 68,
                                          height: 68,
                                          decoration: BoxDecoration(
                                            color: isItem
                                                ? const Color(0xFFFEF3C7)
                                                : const Color(0xFFE0F2FE),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: isItem
                                                  ? const Color(0xFFFDE68A)
                                                  : const Color(0xFFBAE6FD),
                                              width: 1,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                                child: _renderProductImage(
                                                  (product['imageUrl'] ?? '')
                                                      .toString(),
                                                  size: 68,
                                                  isItem: isItem,
                                                ),
                                              ),
                                              if ((product['imageUrl'] ?? '')
                                                  .toString()
                                                  .isNotEmpty)
                                                Positioned(
                                                  right: 4,
                                                  bottom: 4,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          2.5,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.55,
                                                          ),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.zoom_in_rounded,
                                                      color: Colors.white,
                                                      size: 13,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2.5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isItem
                                                        ? const Color(
                                                            0xFFFFFBEB,
                                                          )
                                                        : const Color(
                                                            0xFFF0FDF4,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: isItem
                                                          ? const Color(
                                                              0xFFFDE68A,
                                                            )
                                                          : const Color(
                                                              0xFFBBF7D0,
                                                            ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isItem
                                                        ? '👕 ĐỒ LẺ'
                                                        : '📦 GÓI COMBO',
                                                    style: TextStyle(
                                                      color: isItem
                                                          ? const Color(
                                                              0xFFB45309,
                                                            )
                                                          : const Color(
                                                              0xFF15803D,
                                                            ),
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2.5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isOutOfStock
                                                        ? const Color(
                                                            0xFFFEE2E2,
                                                          )
                                                        : const Color(
                                                            0xFFF1F5F9,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    isOutOfStock
                                                        ? 'Hết hàng'
                                                        : 'Còn hàng ($totalStock)',
                                                    style: TextStyle(
                                                      color: isOutOfStock
                                                          ? const Color(
                                                              0xFFDC2626,
                                                            )
                                                          : const Color(
                                                              0xFF475569,
                                                            ),
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              product['name'] ??
                                                  (isItem
                                                      ? 'Món trang bị lẻ'
                                                      : 'Gói đồng phục'),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: PartnerColors.navy,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _formatVnd(product['price']),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0B926B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // DESCRIPTION / ITEMS INCLUSION
                                if ((product['description'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      product['description'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: PartnerColors.muted,
                                        height: 1.35,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                // SIZES PILLS ROW
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    10,
                                    16,
                                    12,
                                  ),
                                  child: Row(
                                    children: [
                                      const Text(
                                        'Kích thước:',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Wrap(
                                          spacing: 6,
                                          children: ['S', 'M', 'L', 'XL'].map((
                                            s,
                                          ) {
                                            final stock =
                                                int.tryParse(
                                                  sizes[s]?.toString() ?? '0',
                                                ) ??
                                                0;
                                            final hasStock = stock > 0;
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: hasStock
                                                    ? const Color(0xFFF8FAFC)
                                                    : const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: hasStock
                                                      ? const Color(0xFFCBD5E1)
                                                      : const Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              child: Text(
                                                '$s ${hasStock ? '($stock)' : '✕'}',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: hasStock
                                                      ? const Color(0xFF1E293B)
                                                      : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // FOOTER BUTTON
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                    border: Border(
                                      top: BorderSide(color: Color(0xFFEDF2F7)),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        isItem
                                            ? 'Có thể mua thêm bất kỳ lúc nào'
                                            : 'Gói đồng phục tiêu chuẩn',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const Spacer(),
                                      ElevatedButton(
                                        onPressed: isOutOfStock
                                            ? null
                                            : () => _openPurchaseSheet(product),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isItem
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          isOutOfStock
                                              ? 'Hết hàng'
                                              : (isItem
                                                    ? 'Mua đồ lẻ'
                                                    : 'Chọn mua gói'),
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterTab({
    required String id,
    required String title,
    required IconData icon,
  }) {
    final active = categoryFilter == id;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => categoryFilter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal chọn size và thanh toán đặt mua
class _PurchaseModal extends StatefulWidget {
  const _PurchaseModal({
    required this.product,
    required this.session,
    required this.isItem,
    required this.formatVnd,
    required this.cleanPolicy,
    this.onEnlargeImage,
    required this.onSuccess,
  });

  final Map<String, dynamic> product;
  final Session session;
  final bool isItem;
  final String Function(dynamic) formatVnd;
  final String Function(String) cleanPolicy;
  final void Function(Map<String, dynamic> item)? onEnlargeImage;
  final VoidCallback onSuccess;

  @override
  State<_PurchaseModal> createState() => _PurchaseModalState();
}

class _PurchaseModalState extends State<_PurchaseModal> {
  String? selectedSize;
  String paymentMethod = 'AT_OFFICE'; // 'AT_OFFICE' | 'ONLINE'
  bool busy = false;
  String? error;
  String? orderRequestId;
  String? orderRequestPayload;

  @override
  void initState() {
    super.initState();
    final sizes = (widget.product['sizes'] as Map?) ?? {};
    for (final s in ['M', 'L', 'S', 'XL']) {
      final stock = int.tryParse(sizes[s]?.toString() ?? '0') ?? 0;
      if (stock > 0) {
        selectedSize = s;
        break;
      }
    }
  }

  Future<void> _submitOrder() async {
    if (selectedSize == null) {
      setState(() => error = 'Vui lòng chọn kích thước (size).');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });

    try {
      final payload = '${widget.product['id']}:$selectedSize:$paymentMethod';
      if (orderRequestPayload != payload) {
        orderRequestId =
            'shop-ord-${DateTime.now().microsecondsSinceEpoch}-${widget.product['id']}';
        orderRequestPayload = payload;
      }
      final requestId = orderRequestId!;
      await widget.session.request(
        '/partner/uniform-orders',
        method: 'POST',
        body: {
          'packageId': widget.product['id'],
          'size': selectedSize,
          'paymentMethod': paymentMethod,
          'requestId': requestId,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSuccess();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizes = (widget.product['sizes'] as Map?) ?? {};
    final policy = widget.cleanPolicy(widget.product['policy'] ?? '');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // HANDLE
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // HEADER
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap:
                        (widget.product['imageUrl'] ?? '').toString().isNotEmpty
                        ? () => widget.onEnlargeImage?.call(widget.product)
                        : null,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: widget.isItem
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.isItem
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFFBAE6FD),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: _PartnerUniformShopState._renderProductImage(
                              (widget.product['imageUrl'] ?? '').toString(),
                              size: 58,
                              isItem: widget.isItem,
                            ),
                          ),
                          if ((widget.product['imageUrl'] ?? '')
                              .toString()
                              .isNotEmpty)
                            Positioned(
                              right: 3,
                              bottom: 3,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.zoom_in_rounded,
                                  color: Colors.white,
                                  size: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: PartnerColors.navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.formatVnd(widget.product['price']),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0B926B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              if (!widget.isItem &&
                  (widget.product['items'] as List?)?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Các món bao gồm trong gói:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...((widget.product['items'] as List).map((it) {
                        final itemMap = it is Map
                            ? Map<String, dynamic>.from(it)
                            : {'name': it.toString()};
                        final itemName =
                            (itemMap['name'] ?? itemMap['title'] ?? '')
                                .toString();
                        final itemImg = (itemMap['imageUrl'] ?? '').toString();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              if (itemImg.isNotEmpty) ...[
                                GestureDetector(
                                  onTap: () =>
                                      widget.onEnlargeImage?.call(itemMap),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child:
                                          _PartnerUniformShopState._renderProductImage(
                                            itemImg,
                                            size: 32,
                                            isItem: true,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ] else ...[
                                const Text(
                                  '• ',
                                  style: TextStyle(
                                    color: Color(0xFF0B926B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                              Expanded(
                                child: Text(
                                  itemName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      })),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // SIZE SELECTION
              const Text(
                'Chọn kích thước (Size):',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: PartnerColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['S', 'M', 'L', 'XL'].map((s) {
                  final stock = int.tryParse(sizes[s]?.toString() ?? '0') ?? 0;
                  final available = stock > 0;
                  final isSelected = selectedSize == s;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: available
                            ? () => setState(() => selectedSize = s)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !available
                                ? const Color(0xFFF1F5F9)
                                : isSelected
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFCBD5E1),
                              width: isSelected ? 1.8 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                s,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: !available
                                      ? const Color(0xFF94A3B8)
                                      : isSelected
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                available ? 'Còn $stock' : 'Hết',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: !available
                                      ? const Color(0xFF94A3B8)
                                      : isSelected
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // PAYMENT METHOD SELECTION
              const Text(
                'Hình thức thanh toán & nhận đồ:',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: PartnerColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              _buildPaymentOption(
                id: 'AT_OFFICE',
                title: '🏢 Nhận & thanh toán tại TaskLy Hub',
                desc: 'Đến văn phòng TaskLy kiểm tra kích cỡ, nhận đồ và trả tiền mặt/quẹt thẻ.',
              ),
              const SizedBox(height: 8),
              _buildPaymentOption(
                id: 'ONLINE',
                title: '💳 Thanh toán trực tuyến',
                desc:
                    'Thanh toán trực tiếp qua cổng thanh toán bảo mật TaskLy.',
              ),
              const SizedBox(height: 16),

              // POLICY INFO
              if (policy.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          policy,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF475569),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],

              // SUBMIT BUTTON
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: busy ? null : _submitOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Xác nhận đặt ${widget.isItem ? "món lẻ" : "gói đồng phục"}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required String desc,
  }) {
    final isSelected = paymentMethod == id;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => paymentMethod = id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? const Color(0xFF10B981)
                  : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF065F46)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 11,
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
}

/// Modal danh sách đơn hàng đồng phục của đối tác
class _OrderHistoryModal extends StatefulWidget {
  const _OrderHistoryModal({
    required this.orders,
    required this.session,
    required this.formatVnd,
    required this.onReload,
  });

  final List<dynamic> orders;
  final Session session;
  final String Function(dynamic) formatVnd;
  final VoidCallback onReload;

  @override
  State<_OrderHistoryModal> createState() => _OrderHistoryModalState();
}

class _OrderHistoryModalState extends State<_OrderHistoryModal> {
  bool busy = false;
  String? error;
  late List<dynamic> orders = List.of(widget.orders);
  bool loadingOrders = true;

  @override
  void initState() {
    super.initState();
    _reloadOrders();
  }

  Future<void> _reloadOrders() async {
    try {
      final result = await widget.session.request('/partner/uniform-orders');
      if (mounted)
        setState(() {
          orders = result as List;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loadingOrders = false);
    }
  }

  Future<void> _payOrder(String id) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.request(
        '/partner/uniform-orders/$id/payment',
        method: 'POST',
        body: {'result': 'SUCCESS'},
      );
      await _reloadOrders();
      widget.onReload();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đơn trang bị?'),
        content: const Text('Bạn có chắc chắn muốn hủy đơn hàng này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Không'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text(
              'Xác nhận hủy',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => busy = true);
    try {
      await widget.session.request(
        '/partner/uniform-orders/$orderId/cancel',
        method: 'POST',
      );
      await _reloadOrders();
      widget.onReload();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Lịch sử đơn trang bị & đồng phục',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: PartnerColors.navy,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),

          if (error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                error!,
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
              ),
            ),
          ],

          Expanded(
            child: loadingOrders
                ? const Center(child: CircularProgressIndicator())
                : orders.isEmpty
                ? const Center(
                    child: Text(
                      'Bạn chưa có đơn đặt đồng phục nào.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final order = Map<String, dynamic>.from(orders[idx]);
                      final status = order['status'] ?? '';
                      final isReserved = status == 'RESERVED';
                      final isHandedOver = status == 'HANDED_OVER';
                      final isCancelled = status == 'CANCELLED';
                      final isPaid =
                          order['payment_status'] == 'PAID' ||
                          order['payment_status'] == 'WAIVED';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  order['package_name'] ?? 'Đồng phục TaskLy',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: PartnerColors.navy,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isHandedOver
                                        ? const Color(0xFFD1FAE5)
                                        : isCancelled
                                        ? const Color(0xFFFEE2E2)
                                        : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isHandedOver
                                        ? 'Đã bàn giao'
                                        : isCancelled
                                        ? 'Đã hủy'
                                        : 'Chờ nhận tại VP',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isHandedOver
                                          ? const Color(0xFF047857)
                                          : isCancelled
                                          ? const Color(0xFFB91C1C)
                                          : const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  'Size: ${order['size'] ?? ""}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  widget.formatVnd(order['price']),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0B926B),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  isPaid ? 'Đã thanh toán' : 'Chưa thanh toán',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isPaid
                                        ? const Color(0xFF047857)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                            if (isReserved && !isPaid) ...[
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => _payOrder(order['id'].toString()),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Thanh toán giả lập'),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  const Expanded(
                                    child: Text(
                                      'Vui lòng ghé TaskLy Hub để thanh toán & nhận đồng phục',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => _cancelOrder(
                                            order['id']?.toString() ?? '',
                                          ),
                                    child: const Text(
                                      'Hủy đơn',
                                      style: TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
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
