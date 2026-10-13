import 'package:flutter/material.dart';

import 'dart:convert';

import 'support_images.dart';
import 'partner_inbox.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../auth/api.dart';
import 'partner_ui_kit.dart';

/// Trung tâm hỗ trợ toàn diện dành riêng cho Đối tác TaskLy Partner
class PartnerHelpCenter extends StatefulWidget {
  const PartnerHelpCenter({
    super.key,
    required this.session,
    this.initialTab = 0,
  });

  final Session session;
  final int initialTab;

  @override
  State<PartnerHelpCenter> createState() => _PartnerHelpCenterState();
}

class _PartnerHelpCenterState extends State<PartnerHelpCenter>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _faqCategory = 'ALL';

  // Support Ticket Form State
  final _ticketFormKey = GlobalKey<FormState>();
  String _ticketCategory = 'INCOME';
  final TextEditingController _orderIdCtrl = TextEditingController();
  final TextEditingController _subjectCtrl = TextEditingController();
  final TextEditingController _contentCtrl = TextEditingController();
  String _ticketPriority = 'NORMAL';
  bool _isSubmittingTicket = false;

  final List<Map<String, dynamic>> _tickets = [];
  String? _ticketImage, _ticketRequestId;
  Future<void> _loadTickets() async {
    try {
      final messages =
          await widget.session.request('/support/messages') as List;
      if (!mounted) return;
      setState(() {
        _tickets.clear();
        for (final m in messages.where(
          (m) =>
              m['sender'] == 'USER' &&
              m['content'].toString().startsWith('[Ticket CSKH]'),
        )) {
          _tickets.insert(0, {
            'id': m['id'].toString().substring(0, 8),
            'category': 'CSKH',
            'subject':
                m['content'].toString().split('\n').skip(1).firstOrNull ??
                'Ticket CSKH',
            'content': m['content'],
            'status': 'PENDING',
            'statusText': 'Đã gửi CSKH',
            'reply': 'Mở cuộc trò chuyện CSKH để theo dõi phản hồi.',
            'time': m['created_at'].toString(),
          });
        }
      });
    } catch (_) {}
  }

  Future<void> _pickTicketImage() async {
    try {
      final image = await pickSupportImage();
      if (mounted && image != null) setState(() => _ticketImage = image);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _openSupportChat() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SupportConversation(session: widget.session),
    ),
  );

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _orderIdCtrl.dispose();
    _subjectCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showCallDialog(phoneNumber);
      }
    } catch (_) {
      _showCallDialog(phoneNumber);
    }
  }

  void _showCallDialog(String phoneNumber) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tổng đài hỗ trợ đối tác'),
        content: Text(
          'Số hotline: $phoneNumber\n(Hoạt động 24/7, cước gọi tiêu chuẩn)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitTicket() async {
    if (_isSubmittingTicket ||
        !(_ticketFormKey.currentState?.validate() ?? false))
      return;
    setState(() => _isSubmittingTicket = true);
    final category = switch (_ticketCategory) {
      'INCOME' => 'Thu nhập & Đối soát',
      'ORDER' => 'Khách hàng & Đơn hàng',
      'ACCOUNT' => 'Tài khoản & KYC',
      'UNIFORM' => 'Đồng phục & Dụng cụ',
      _ => 'Góp ý & Khiếu nại khác',
    };
    _ticketRequestId ??= supportRequestId();
    try {
      await widget.session.request(
        '/support/messages',
        method: 'POST',
        body: {
          'requestId': _ticketRequestId,
          'text':
              '[Ticket CSKH]\n${_subjectCtrl.text.trim()}\nDanh mục: $category\nMã đơn: ${_orderIdCtrl.text.trim().isEmpty ? 'Không có' : _orderIdCtrl.text.trim()}\nMức độ: ${_ticketPriority == 'URGENT' ? 'Khẩn cấp' : 'Bình thường'}\n${_contentCtrl.text.trim()}',
          if (_ticketImage != null) 'imageData': _ticketImage,
        },
      );
      if (!mounted) return;
      _ticketRequestId = null;
      _ticketImage = null;
      _subjectCtrl.clear();
      _contentCtrl.clear();
      _orderIdCtrl.clear();
      await _loadTickets();
      if (mounted) _openSupportChat();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa gửi được ticket. Nội dung được giữ lại, vui lòng thử lại.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _isSubmittingTicket = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: PartnerColors.navy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Trung tâm hỗ trợ Đối tác',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: PartnerColors.navy,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'TaskLy Partner Support 24/7',
              style: TextStyle(
                fontSize: 11,
                color: PartnerColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Gọi hotline khẩn cấp 1900 8868',
            onPressed: () => _makeCall('19008868'),
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Icon(
                Icons.phone_in_talk_rounded,
                color: Color(0xFF1D4ED8),
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: '⚡ Tổng quan & SOS'),
                Tab(text: '🚨 Báo sự cố ca làm'),
                Tab(text: '📝 Gửi Ticket CSKH'),
                Tab(text: '❓ Hỏi đáp (FAQ)'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildIncidentTab(),
          _buildTicketTab(),
          _buildFaqTab(),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: TỔNG QUAN & SOS
  // -------------------------------------------------------------
  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. SOS Emergency Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFECDD3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0CBE123C),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HOTLINE KHẨN CẤP 24/7',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFBE123C),
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '1900 8868 hoặc 0909 876 902',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF881337),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Ưu tiên kết nối trực tiếp tổng đài viên khi xảy ra sự cố an toàn, đe dọa quấy rối, hoặc tai nạn giao thông trong ca làm việc.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9F1239),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _makeCall('19008868'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text(
                        'Gọi Tổng Đài 1900 8868',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => _tabController.animateTo(1),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFDA4AF)),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                    ),
                    child: const Text(
                      'Báo Sự Cố',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFBE123C),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 2. 4 Quick Access Cards
        const Text(
          'Kênh hỗ trợ nhanh',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: PartnerColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _quickCard(
                icon: '🚨',
                title: 'Báo sự cố',
                subtitle: 'Khách vắng, hủy việc',
                onTap: () => _tabController.animateTo(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickCard(
                icon: '📝',
                title: 'Gửi ticket',
                subtitle: 'Hỗ trợ ví & tài khoản',
                onTap: () => _tabController.animateTo(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _quickCard(
                icon: '❓',
                title: 'Hỏi đáp (FAQ)',
                subtitle: 'Quy trình & chính sách',
                onTap: () => _tabController.animateTo(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickCard(
                icon: '🏢',
                title: 'TaskLy Hub',
                subtitle: 'Văn phòng tiếp đón',
                onTap: _showHubLocationDialog,
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // 3. Quy chuẩn quyền lợi đối tác
        const Text(
          'Chính sách bảo vệ Đối tác TaskLy Care',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: PartnerColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        _benefitBanner(
          emoji: '🛡️',
          title: 'Bảo hiểm tai nạn lên đến 50.000.000 đ',
          desc: 'Tự động kích hoạt cho mọi đơn hàng từ khi bấm "Đang di chuyển" đến lúc hoàn tất nghiệm thu.',
        ),
        const SizedBox(height: 10),
        _benefitBanner(
          emoji: '💰',
          title: 'Cam kết bù phí di chuyển 50.000 đ',
          desc: 'Khi khách hàng vắng mặt không lý do hoặc hủy đơn sát giờ (< 15 phút trước giờ hẹn).',
        ),
        const SizedBox(height: 10),
        _benefitBanner(
          emoji: '⚖️',
          title: 'Phúc khảo đánh giá 1-2 sao oan',
          desc: 'Gỡ bỏ ngay lập tức nếu lỗi thuộc về địa chỉ sai hoặc yêu cầu vô lý từ khách hàng.',
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _quickCard({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: PartnerColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefitBanner({
    required String emoji,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PartnerColors.navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: BÁO SỰ CỐ CA LÀM
  // -------------------------------------------------------------
  Widget _buildIncidentTab() {
    final incidents = [
      {
        'emoji': '🚪',
        'title': 'Khách không có nhà / Không mở cửa',
        'tag': 'Phổ biến',
        'tagColor': const Color(0xFF2563EB),
        'guide': '1. Gọi cho khách ít nhất 3 cuộc cách nhau 3 phút.\n2. Chụp ảnh trước cửa nhà / số nhà làm bằng chứng.\n3. Chờ đủ 15 phút từ giờ hẹn.\n4. Bấm kích hoạt hủy - Hệ thống tự động bù 50.000đ tiền xăng xe.',
        'actionLabel': 'Khai báo khách vắng mặt',
      },
      {
        'emoji': '⚠️',
        'title': 'Khách yêu cầu việc nguy hiểm / quá tải',
        'tag': 'An toàn',
        'tagColor': const Color(0xFFDC2626),
        'guide': '1. Đối tác có quyền TỪ CHỐI leo cao ngoài ban công > 2m, bê vác đồ nặng > 30kg, hoặc dùng hóa chất lạ không rõ nguồn gốc.\n2. Giải thích nhẹ nhàng đây là quy định an toàn của TaskLy.\n3. Nếu khách ép buộc, báo ngay cho tổng đài để hủy miễn phạt.',
        'actionLabel': 'Báo cáo việc ngoài phạm vi',
      },
      {
        'emoji': '📍',
        'title': 'Địa chỉ khách hàng sai lệch quá xa (> 5km)',
        'tag': 'Vị trí',
        'tagColor': const Color(0xFFD97706),
        'guide': '1. Nếu khách yêu cầu di chuyển sang địa chỉ mới xa hơn 3km, khách phải trả thêm phụ phí 10.000đ/km.\n2. Nếu không đồng ý, đối tác có quyền hủy việc mà không bị trừ điểm tỷ lệ nhận việc.',
        'actionLabel': 'Báo sai địa chỉ',
      },
      {
        'emoji': '💵',
        'title': 'Khách không chịu thanh toán tiền mặt',
        'tag': 'Thu nhập',
        'tagColor': const Color(0xFF059669),
        'guide': '1. Tuyệt đối không cãi vã hoặc to tiếng với khách hàng.\n2. Hướng dẫn khách bấm chuyển sang thanh toán QR hoặc Chuyển khoản ví TaskLy.\n3. Nếu khách cố tình quỵt tiền, bấm báo cáo ngay, TaskLy sẽ đền bù 100% tiền công sau khi xác minh.',
        'actionLabel': 'Báo sự cố thanh toán',
      },
      {
        'emoji': '🛡️',
        'title': 'Sự cố tai nạn hoặc quấy rối / đe dọa',
        'tag': 'Khẩn cấp',
        'tagColor': const Color(0xFF991B1B),
        'guide': '1. Ngay lập tức rời khỏi khu vực nguy hiểm.\n2. Gọi hotline khẩn cấp 1900 8868 hoặc 113 nếu bị đe dọa an toàn thân thể.\n3. Bảo hiểm TaskLy Care chi trả toàn bộ viện phí nếu xảy ra thương tật.',
        'actionLabel': 'Khai báo khẩn cấp (SOS)',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: const [
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF1D4ED8),
                size: 22,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chọn tình huống thực tế bên dưới để được hướng dẫn xử lý chuẩn xác và bảo vệ điểm tín nhiệm.',
                  style: TextStyle(
                    color: Color(0xFF1E40AF),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...incidents.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                alignment: Alignment.center,
                child: Text(
                  item['emoji'] as String,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              title: Text(
                item['title'] as String,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: PartnerColors.navy,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: (item['tagColor'] as Color).withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item['tag'] as String,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: item['tagColor'] as Color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item['guide'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF334155),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _showReportIncidentDialog(item['title'] as String);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    child: Text(
                      item['actionLabel'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _showReportIncidentDialog(String title) async {
    final noteCtrl = TextEditingController();
    String? image, error;
    final requestId = supportRequestId();
    bool sending = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Mô tả sự cố để gửi đến CSKH và trao đổi trong cuộc trò chuyện.',
                ),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  maxLength: 2500,
                  enabled: !sending,
                  decoration: const InputDecoration(
                    hintText: 'Mô tả sự cố...',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (image != null)
                  Image.memory(
                    base64Decode(image!.split(',').last),
                    height: 100,
                  ),
                TextButton.icon(
                  onPressed: sending
                      ? null
                      : () async {
                          try {
                            final picked = await pickSupportImage();
                            if (ctx.mounted && picked != null)
                              update(() => image = picked);
                          } catch (e) {
                            if (ctx.mounted) update(() => error = e.toString());
                          }
                        },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(image == null ? 'Thêm ảnh' : 'Đổi ảnh'),
                ),
                if (image != null)
                  TextButton(
                    onPressed: sending
                        ? null
                        : () => update(() => image = null),
                    child: const Text('Xóa ảnh'),
                  ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: sending
                  ? null
                  : () async {
                      if (noteCtrl.text.trim().isEmpty) {
                        update(() => error = 'Vui lòng mô tả sự cố.');
                        return;
                      }
                      update(() => sending = true);
                      try {
                        await widget.session.request(
                          '/support/messages',
                          method: 'POST',
                          body: {
                            'requestId': requestId,
                            'text':
                                '[Báo cáo sự cố]\n$title\n${noteCtrl.text.trim()}',
                            if (image != null) 'imageData': image,
                          },
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) _openSupportChat();
                      } catch (e) {
                        if (ctx.mounted)
                          update(() {
                            sending = false;
                            error = 'Không gửi được báo cáo. Vui lòng thử lại.';
                          });
                      }
                    },
              child: Text(sending ? 'Đang gửi...' : 'Gửi CSKH'),
            ),
          ],
        ),
      ),
    );
    noteCtrl.dispose();
  }

  // -------------------------------------------------------------
  // TAB 3: GỬI TICKET CSKH
  // -------------------------------------------------------------
  Widget _buildTicketTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(onPressed:_openSupportChat,icon:const Icon(Icons.chat_outlined),label:const Text('Mở cuộc trò chuyện CSKH')),
        const SizedBox(height:12),
        // Form tạo phiếu
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Form(
            key: _ticketFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      color: Color(0xFF2563EB),
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tạo phiếu yêu cầu mới',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: PartnerColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Chọn danh mục
                const Text(
                  'Danh mục cần hỗ trợ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _ticketCategory,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'INCOME',
                      child: Text('Thu nhập & Đối soát ví Tasker'),
                    ),
                    DropdownMenuItem(
                      value: 'ORDER',
                      child: Text('Khách hàng & Tranh chấp đơn hàng'),
                    ),
                    DropdownMenuItem(
                      value: 'ACCOUNT',
                      child: Text('Tài khoản, CCCD & Hồ sơ KYC'),
                    ),
                    DropdownMenuItem(
                      value: 'UNIFORM',
                      child: Text('Đồng phục & Trang bị hành nghề'),
                    ),
                    DropdownMenuItem(
                      value: 'OTHER',
                      child: Text('Khiếu nại & Đóng góp ý kiến'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _ticketCategory = val);
                  },
                ),
                const SizedBox(height: 12),

                // Mã đơn hàng (tùy chọn)
                const Text(
                  'Mã đơn hàng liên quan (nếu có)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _orderIdCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: #TSK-8921',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Tiêu đề
                const Text(
                  'Tiêu đề tóm tắt',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _subjectCtrl,
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Vui lòng nhập tiêu đề'
                      : null,
                  decoration: InputDecoration(
                    hintText:
                        'Ví dụ: Cần đối soát lại tiền tip khách chuyển qua app',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Nội dung
                const Text(
                  'Nội dung chi tiết',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _contentCtrl,
                  maxLines: 4,
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'Vui lòng nhập nội dung chi tiết'
                      : null,
                  decoration: InputDecoration(
                    hintText: 'Mô tả rõ ràng vấn đề để chuyên viên xử lý nhanh nhất...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Mức độ ưu tiên
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const Text(
                      'Mức độ:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Bình thường'),
                      selected: _ticketPriority == 'NORMAL',
                      onSelected: (s) =>
                          setState(() => _ticketPriority = 'NORMAL'),
                    ),
                    ChoiceChip(
                      label: const Text('Khẩn cấp (Trong ca)'),
                      selected: _ticketPriority == 'URGENT',
                      onSelected: (s) =>
                          setState(() => _ticketPriority = 'URGENT'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Nút gửi
                if (_ticketImage != null)
                  Row(
                    children: [
                      Image.memory(
                        base64Decode(_ticketImage!.split(',').last),
                        width: 80,
                        height: 80,
                      ),
                      IconButton(
                        onPressed: _isSubmittingTicket
                            ? null
                            : () => setState(() => _ticketImage = null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                OutlinedButton.icon(
                  onPressed: _isSubmittingTicket ? null : _pickTicketImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Đính kèm ảnh (PNG/JPEG, tối đa 2 MB)'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmittingTicket ? null : _submitTicket,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: _isSubmittingTicket
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Gửi phiếu yêu cầu hỗ trợ',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Lịch sử phiếu yêu cầu
        const Text(
          'Lịch sử yêu cầu hỗ trợ của bạn',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: PartnerColors.navy,
          ),
        ),
        const SizedBox(height: 12),

        ..._tickets.map((t) {
          final isResolved = t['status'] == 'RESOLVED';
          final isProcessing = t['status'] == 'PROCESSING';

          Color badgeBg = isResolved
              ? const Color(0xFFE5FAF1)
              : isProcessing
              ? const Color(0xFFFEF3C7)
              : const Color(0xFFEFF6FF);
          Color badgeFg = isResolved
              ? const Color(0xFF0B926B)
              : isProcessing
              ? const Color(0xFFD97706)
              : const Color(0xFF2563EB);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t['id'] as String,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t['statusText'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: badgeFg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  t['subject'] as String,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: PartnerColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t['content'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💬', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Phản hồi từ CSKH:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t['reply'] as String,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF475569),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cập nhật: ${t['time']}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 4: HỎI ĐÁP (FAQ)
  // -------------------------------------------------------------
  Widget _buildFaqTab() {
    final faqs = [
      {
        'category': 'INCOME',
        'q': 'Khi nào tiền công việc được cộng vào ví Tasker?',
        'a': 'Tiền được cộng tự động vào Ví Tasker ngay sau khi khách hàng xác nhận nghiệm thu trên ứng dụng hoặc sau 2 giờ kể từ lúc bạn bấm "Hoàn tất". Đối tác có thể rút về tài khoản ngân hàng bất kỳ lúc nào.',
      },
      {
        'category': 'INCOME',
        'q': 'Thực nhận được tính thế nào?',
        'a': 'Thực nhận là tiền dịch vụ sau khi trừ phí sàn do Admin cấu hình cho từng dịch vụ. Số tiền này hiển thị trước khi nhận việc và được giữ cố định khi nhận việc.',
      },
      {
        'category': 'INCOME',
        'q': 'Làm thế nào để rút tiền về ngân hàng chính chủ?',
        'a': 'Vào mục Tài khoản > Ví Tasker > Bấm "Rút tiền". Tiền sẽ chuyển vào tài khoản ngân hàng chính chủ đã đăng ký trong vòng 5 - 15 phút (hỗ trợ chuyển nhanh 24/7 NAPAS).',
      },
      {
        'category': 'ORDER',
        'q': 'Nếu khách hàng đánh giá 1-2 sao oan thì xử lý ra sao?',
        'a': 'TaskLy có cơ chế phúc khảo công bằng. Bạn gửi ticket kèm bằng chứng hình ảnh nghiệm thu. Ban kiểm soát chất lượng sẽ lắng nghe và gỡ bỏ đánh giá xấu nếu khách hàng đòi hỏi ngoài phạm vi thỏa thuận.',
      },
      {
        'category': 'ORDER',
        'q': 'Hủy đơn hàng có bị phạt điểm tín nhiệm không?',
        'a': 'Hủy trước giờ hẹn > 4 tiếng: Không phạt. Hủy sát giờ (< 2 tiếng) bị trừ 5 điểm tín nhiệm. Nếu có lý do bất khả kháng (xe hỏng, thời tiết ngập lụt, khách sai địa chỉ) và có báo tổng đài thì sẽ được miễn trừ hoàn toàn.',
      },
      {
        'category': 'UNIFORM',
        'q': 'Quy định đồng phục TaskLy khi nhận việc?',
        'a': 'Đối tác bắt buộc mặc áo thun hoặc tạp dề TaskLy chính hãng, mang giày quai hậu/thể thao kín mũi, và đeo thẻ đối tác trong suốt thời gian làm việc để tạo niềm tin với khách hàng.',
      },
      {
        'category': 'SAFETY',
        'q': 'Quyền lợi bảo hiểm tai nạn TaskLy Care 50.000.000 đ?',
        'a': 'Mọi đối tác trong ca làm việc đều được tự động bảo vệ bảo hiểm tai nạn lên đến 50.000.000đ/vụ. Khi xảy ra sự cố trên đường di chuyển hoặc tại nơi làm việc, hãy gọi ngay 1900 8868 để kích hoạt bồi thường viện phí.',
      },
      {
        'category': 'ACCOUNT',
        'q': 'Tài khoản bị tạm khóa do đánh giá thấp cần làm gì?',
        'a': 'Tài khoản có tỷ lệ hài lòng dưới 4.2 sao sẽ tạm ngưng nhận việc trong 48 giờ để tham gia khóa đào tạo nâng cao nghiệp vụ (Academy trực tuyến). Sau khi hoàn thành bài kiểm tra, tài khoản sẽ tự động mở lại.',
      },
    ];

    final filtered = faqs.where((f) {
      final matchCat = _faqCategory == 'ALL' || f['category'] == _faqCategory;
      final matchQuery =
          _searchQuery.isEmpty ||
          f['q']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f['a']!.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchQuery;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Ô tìm kiếm
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Tìm câu hỏi, chính sách, quy định...',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Filter chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('ALL', 'Tất cả'),
            _chip('INCOME', 'Thu nhập & Ví'),
            _chip('ORDER', 'Nhận việc & Hủy đơn'),
            _chip('UNIFORM', 'Đồng phục'),
            _chip('SAFETY', 'Bảo hiểm & An toàn'),
            _chip('ACCOUNT', 'Tài khoản'),
          ],
        ),
        const SizedBox(height: 16),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: const Column(
              children: [
                Text('🔍', style: TextStyle(fontSize: 32)),
                SizedBox(height: 8),
                Text(
                  'Không tìm thấy câu hỏi phù hợp',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: PartnerColors.navy,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Thử từ khóa khác hoặc chuyển sang tab "Gửi Ticket" để hỏi CSKH.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else
          ...filtered.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                title: Text(
                  item['q']!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: PartnerColors.navy,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item['a']!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF334155),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _chip(String key, String label) {
    final isSelected = _faqCategory == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _faqCategory = key),
      selectedColor: const Color(0xFF2563EB),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
    );
  }

  void _showHubLocationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Văn phòng TaskLy Partner Hub',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _hubItem(
                city: 'TP. HỒ CHÍ MINH (Trụ sở chính)',
                address: 'Tầng 3, TaskLy Partner Hub, 123 Nguyễn Thị Minh Khai, P. Bến Thành, Quận 1',
                phone: '028 7300 8868',
                hours: 'Thứ 2 – Thứ 7: 08:00 – 17:30',
              ),
              const Divider(height: 24),
              _hubItem(
                city: 'HÀ NỘI (Văn phòng miền Bắc)',
                address:
                    'Tầng 5, TaskLy Hub Hà Nội, 88 Phố Huế, Q. Hai Bà Trưng',
                phone: '024 7300 8868',
                hours: 'Thứ 2 – Thứ 7: 08:00 – 17:30',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _makeCall('02873008868');
            },
            child: const Text('Gọi đặt hẹn'),
          ),
        ],
      ),
    );
  }

  Widget _hubItem({
    required String city,
    required String address,
    required String phone,
    required String hours,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          city,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
            color: Color(0xFF1D4ED8),
          ),
        ),
        const SizedBox(height: 4),
        Text('📍 $address', style: const TextStyle(fontSize: 12, height: 1.35)),
        const SizedBox(height: 2),
        Text(
          '📞 Điện thoại: $phone',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          '🕒 Giờ làm việc: $hours',
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}
