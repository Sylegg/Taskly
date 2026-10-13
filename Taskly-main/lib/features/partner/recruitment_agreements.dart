import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/api.dart';
import 'partner_ui_kit.dart';
import 'recruitment_status_message.dart';

class RecruitmentAgreements extends StatefulWidget {
  const RecruitmentAgreements({super.key, required this.session});
  final Session session;

  @override
  State<RecruitmentAgreements> createState() => _RecruitmentAgreementsState();
}

class _RecruitmentAgreementsState extends State<RecruitmentAgreements> {
  final ScrollController _scrollController = ScrollController();
  List<dynamic> docs = [];
  bool isAgreedAll = false;
  bool busy = false;
  bool _hasReachedBottom = false;
  String? error;
  Map<String, dynamic>? application;
  String get reviewMessage => recruitmentStatusMessage(application ?? {}).$2;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasReachedBottom || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels > 0 && position.extentAfter <= 24) {
      setState(() => _hasReachedBottom = true);
    }
  }

  bool get allAccepted =>
      docs.isNotEmpty && docs.every((d) => d['accepted'] == true);

  String _formatDocTitle(dynamic doc) {
    final rawType = doc['documentType']?.toString() ?? '';
    return switch (rawType) {
      'PARTNER_CONDUCT' => 'Quy tắc ứng xử và tiêu chuẩn dịch vụ',
      'PARTNER_SAFETY' => 'Chính sách an toàn & bảo vệ tài sản khách hàng',
      'PARTNER_COOPERATION' => 'Thỏa thuận hợp tác đối tác TaskLy Partner',
      'PARTNER_PRIVACY' => 'Chính sách bảo mật và dữ liệu người dùng',
      'PARTNER_UNIFORM' => 'Cam kết minh bạch giá và chính sách đồng phục',
      _ => rawType.isNotEmpty ? rawType : 'Văn bản cam kết dịch vụ',
    };
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.session.request('/partner/agreements');
      final currentApplication = await widget.session.request('/partner/onboarding');
      if (result is! List || result.isEmpty) {
        throw StateError('Chưa có cam kết được cấu hình trên hệ thống.');
      }
      if (mounted) {
        setState(() {
          application = Map<String, dynamic>.from(currentApplication);
          docs = result;
          isAgreedAll = allAccepted;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          docs = [];
          error = 'Không tải được cam kết: $e';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _acceptAllAgreements() async {
    if (!_hasReachedBottom || !isAgreedAll || busy || docs.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final application = await widget.session.request(
        '/partner/agreements/accept-all',
        method: 'POST',
      );
      final result = await widget.session.request('/partner/agreements');
      final currentApplication = await widget.session.request('/partner/onboarding');
      if (result is! List ||
          result.isEmpty ||
          !result.every((doc) => doc['accepted'] == true) ||
          application['eligibility']?['agreements_current'] != true) {
        throw StateError('Cam kết chưa được lưu đầy đủ trên hệ thống.');
      }
      if (!mounted) return;
      setState(() { docs = result; this.application = Map<String, dynamic>.from(currentApplication); });

      // Hiển thị thông báo sau khi bấm xác nhận cam kết
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Color(0xFF10B981),
              size: 36,
            ),
          ),
          title: const Text(
            'Ký cam kết thành công',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            reviewMessage,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF334155),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: PartnerColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text(
                  'Đã hiểu',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reviewMessage,
          ),
          backgroundColor: Color(0xFF0F172A),
          duration: Duration(seconds: 4),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = 'Chưa lưu được cam kết: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = allAccepted;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          'Cam kết đối tác TaskLy',
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
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFFECFDF5) : PartnerColors.softBlue,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDone
                    ? const Color(0xFFA7F3D0)
                    : PartnerColors.softBlueBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDone
                      ? Icons.check_circle_rounded
                      : Icons.verified_user_rounded,
                  size: 14,
                  color: isDone
                      ? const Color(0xFF10B981)
                      : PartnerColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  isDone ? 'Đã ký kết' : '05 Cam kết',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDone
                        ? const Color(0xFF059669)
                        : PartnerColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: busy && docs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              controller: _scrollController,
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
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFDC2626),
                          size: 20,
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

                // Hero Header Banner
                _buildHeroBanner(isDone),

                const SizedBox(height: 16),

                // Main unified readable contract container
                _buildContractDocument(),

                const SizedBox(height: 20),

                // Bottom confirmation box: tick 1 lần và bấm xác nhận
                _buildBottomConfirmationBox(isDone),

                const SizedBox(height: 16),

                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Quay về danh mục hồ sơ'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeroBanner(bool isDone) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isDone
                      ? const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        )
                      : PartnerColors.luxuryBlueGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDone ? Icons.verified_rounded : Icons.gavel_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDone
                          ? 'Cam kết đối tác đã có hiệu lực'
                          : 'Cam kết tiêu chuẩn dịch vụ',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDone
                          ? 'Đã ghi nhận chữ ký điện tử trên hệ thống'
                          : 'Đọc 1 lần, kéo xuống cuối để tick và xác nhận',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDone
                            ? const Color(0xFF059669)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isDone
                      ? Icons.check_circle_outline_rounded
                      : Icons.touch_app_rounded,
                  size: 16,
                  color: isDone
                      ? const Color(0xFF059669)
                      : PartnerColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isDone
                        ? 'Bạn đã hoàn tất đầy đủ 05 văn bản cam kết tiêu chuẩn đối tác TaskLy.'
                        : 'Bạn chỉ cần đọc nội dung dưới đây, cuộn xuống cuối trang để tick đồng ý một lần duy nhất và bấm xác nhận.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDone
                          ? const Color(0xFF047857)
                          : PartnerColors.primaryDark,
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

  Widget _buildContractDocument() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // National Emblem & Contract Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                const Text(
                  'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Độc lập - Tự do - Hạnh phúc',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    color: Color(0xFF334155),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                const Text(
                  'BẢN CAM KẾT VÀ QUY CHẾ HOẠT ĐỘNG ĐỐI TÁC',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E3A8A),
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  '(Áp dụng đồng bộ cho tất cả Tasker đối tác TaskLy trên toàn quốc)',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION 1
                _buildSectionItem(
                  index: '01',
                  docKey: 'PARTNER_CONDUCT',
                  title: 'Quy tắc ứng xử và tiêu chuẩn dịch vụ (v2.0)',
                  badgeColor: const Color(0xFF3B82F6),
                  icon: Icons.star_rounded,
                  clauses: const [
                    'Điều 1.1 - Tác phong & Giờ giấc: Đối tác cam kết có mặt tại địa điểm cung ứng dịch vụ đúng giờ đã thỏa thuận (khuyến khích đến trước 10 phút). Tuyệt đối không hủy đơn sát giờ nếu không có lý do bất khả kháng.',
                    'Điều 1.2 - Thái độ phục vụ 5 sao: Giữ thái độ văn minh, nhã nhặn, tôn trọng và tận tâm với khách hàng. Tuyệt đối không sử dụng ngôn từ thiếu lịch sự, không tranh cãi hoặc thể hiện hành vi tiêu cực.',
                    'Điều 1.3 - Trung thực tuyệt đối: Nghiêm cấm nhận tiền ngoài luồng, không thu vượt mức giá hiển thị, bảo quản toàn vẹn tài sản của khách hàng trong suốt ca làm việc.',
                  ],
                ),

                const Divider(height: 28, color: Color(0xFFF1F5F9)),

                // SECTION 2
                _buildSectionItem(
                  index: '02',
                  docKey: 'PARTNER_SAFETY',
                  title:
                      'Chính sách an toàn & bảo vệ tài sản khách hàng (v1.8)',
                  badgeColor: const Color(0xFF10B981),
                  icon: Icons.security_rounded,
                  clauses: const [
                    'Điều 2.1 - An toàn lao động: Tuân thủ đầy đủ quy định an toàn về điện, nước, hóa chất tẩy rửa và trang bị bảo hộ cần thiết trong suốt quá trình thao tác.',
                    'Điều 2.2 - Trách nhiệm bảo vệ tài sản: Đối tác có nghĩa vụ cẩn trọng tối đa với trang thiết bị, nội thất của khách hàng. Tuyệt đối không tự ý chạm vào đồ dùng có giá trị không thuộc phạm vi công việc.',
                    'Điều 2.3 - Xử lý sự cố & Bồi thường: Trong trường hợp phát sinh hư hỏng đồ vật, đối tác phải chụp ảnh giữ nguyên hiện trường, thông báo ngay cho TaskLy trong vòng 15 phút để kích hoạt gói bảo hiểm bảo hộ trách nhiệm nghề nghiệp.',
                  ],
                ),

                const Divider(height: 28, color: Color(0xFFF1F5F9)),

                // SECTION 3
                _buildSectionItem(
                  index: '03',
                  docKey: 'PARTNER_COOPERATION',
                  title: 'Thỏa thuận hợp tác đối tác TaskLy Partner (v2.1)',
                  badgeColor: const Color(0xFF8B5CF6),
                  icon: Icons.handshake_rounded,
                  clauses: const [
                    'Điều 3.1 - Tư cách đối tác độc lập: Tasker hợp tác với tư cách đối tác tự do, có quyền tự chủ thời gian làm việc, bật/tắt nhận việc tùy theo lịch rảnh cá nhân.',
                    'Điều 3.2 - Phân chia thu nhập & Đối soát: Thu nhập được kết chuyển và đối soát tự động vào Ví Tasker ngay sau khi khách hàng xác nhận nghiệm thu. Đối tác có quyền rút tiền về tài khoản ngân hàng chính chủ.',
                    'Điều 3.3 - Chuẩn chất lượng (SLA): Duy trì điểm đánh giá trung bình từ 4.5 sao trở lên để giữ thứ hạng ưu tiên phân phối việc và hưởng các chính sách thưởng tuần/tháng.',
                  ],
                ),

                const Divider(height: 28, color: Color(0xFFF1F5F9)),

                // SECTION 4
                _buildSectionItem(
                  index: '04',
                  docKey: 'PARTNER_PRIVACY',
                  title: 'Chính sách bảo mật và dữ liệu người dùng (v1.5)',
                  badgeColor: const Color(0xFFEC4899),
                  icon: Icons.lock_outline_rounded,
                  clauses: const [
                    'Điều 4.1 - Tuyệt đối bảo mật thông tin: Không lưu trữ, sao chép hoặc chia sẻ số điện thoại, địa chỉ nhà, thông tin gia đình của khách hàng cho bất kỳ bên thứ ba nào.',
                    'Điều 4.2 - Cấm quay chụp không gian riêng tư: Tuyệt đối không chụp ảnh, quay video không gian sống của khách hàng đăng tải lên mạng xã hội. Mọi hình ảnh công việc chỉ được sử dụng cho mục đích báo cáo tiến độ trên ứng dụng.',
                    'Điều 4.3 - Chế tài xử lý: Vi phạm bảo mật thông tin sẽ bị khóa tài khoản vĩnh viễn và chuyển giao cơ quan pháp luật xử lý theo Nghị định 13/2023/NĐ-CP về bảo vệ dữ liệu cá nhân.',
                  ],
                ),

                const Divider(height: 28, color: Color(0xFFF1F5F9)),

                // SECTION 5
                _buildSectionItem(
                  index: '05',
                  docKey: 'PARTNER_UNIFORM',
                  title: 'Cam kết minh bạch giá và chính sách đồng phục (v1.2)',
                  badgeColor: const Color(0xFFF59E0B),
                  icon: Icons.badge_rounded,
                  clauses: const [
                    'Điều 5.1 - Minh bạch giá cả: Thu đúng số tiền thể hiện trên ứng dụng TaskLy. Nghiêm cấm mọi hành vi vòi vĩnh, đòi hỏi phụ phí hay tiền boa (tip) ngoài hệ thống.',
                    'Điều 5.2 - Đồng phục nhận diện chuẩn mực: Mặc áo đồng phục TaskLy sạch sẽ, mang thẻ Tasker chính quy và mang giày dép lịch sự khi đến phục vụ tại nhà khách hàng.',
                    'Điều 5.3 - Giữ gìn hình ảnh thương hiệu: Không sử dụng chất kích thích, không hút thuốc lá trong suốt thời gian cung ứng dịch vụ tại nhà hoặc khuôn viên của khách hàng.',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionItem({
    required String index,
    required String docKey,
    required String title,
    required Color badgeColor,
    required IconData icon,
    required List<String> clauses,
  }) {
    // Tìm URL văn bản gốc nếu có
    final docData = docs.cast<dynamic>().firstWhere(
      (d) =>
          d['documentType'] == docKey ||
          d['id'] == docKey ||
          d['documentType'] == title ||
          _formatDocTitle(d) == title,
      orElse: () => null,
    );
    final contentUrl = docData?['contentUrl']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'MỤC $index',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 16, color: badgeColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...clauses.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 5, right: 8),
                  child: Icon(Icons.circle, size: 5, color: Color(0xFF94A3B8)),
                ),
                Expanded(
                  child: Text(
                    c,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (contentUrl != null && contentUrl.startsWith('http'))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () async {
                final uri = Uri.parse(contentUrl);
                if (!await launchUrl(uri) && mounted) {
                  setState(() => error = 'Không mở được liên kết tài liệu.');
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 13),
              label: const Text(
                'Xem văn bản gốc đầy đủ',
                style: TextStyle(fontSize: 11.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomConfirmationBox(bool isDone) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? const Color(0xFFA7F3D0)
              : PartnerColors.softBlueBorder,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C1E40AF),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isDone
                    ? Icons.verified_rounded
                    : Icons.check_circle_outline_rounded,
                color: isDone ? const Color(0xFF059669) : PartnerColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDone
                      ? 'XÁC NHẬN CAM KẾT HOÀN TẤT'
                      : 'XÁC NHẬN CAM KẾT ĐỐI TÁC',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: isDone
                        ? const Color(0xFF065F46)
                        : PartnerColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isDone) ...[
            const Text(
              '✓ Bạn đã hoàn thành ký cam kết trực tuyến. Toàn bộ các quy chế và điều khoản có hiệu lực trong suốt thời gian bạn hoạt động trên nền tảng TaskLy.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF047857),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      reviewMessage,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92400E),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text(
                'Đã hoàn tất • Về hồ sơ',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ] else ...[
            // Single Checkbox (Tick 1 lần là được)
            InkWell(
              onTap: busy || !_hasReachedBottom
                  ? null
                  : () => setState(() => isAgreedAll = !isAgreedAll),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isAgreedAll,
                        onChanged: busy || !_hasReachedBottom
                            ? null
                            : (v) => setState(() => isAgreedAll = v ?? false),
                        activeColor: PartnerColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tôi đã đọc kỹ, hiểu rõ và đồng ý với tất cả 05 cam kết tiêu chuẩn đối tác nêu trên.',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              height: 1.35,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tôi cam kết tuân thủ nghiêm túc các quy tắc và chịu trách nhiệm trước pháp luật cũng như nền tảng TaskLy.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF64748B),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Single Confirmation Button (bấm xác nhận)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: (isAgreedAll && !busy && _hasReachedBottom)
                    ? PartnerColors.luxuryBlueGradient
                    : null,
                color: (isAgreedAll && !busy && _hasReachedBottom)
                    ? null
                    : const Color(0xFFCBD5E1),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (isAgreedAll && !busy && _hasReachedBottom)
                      ? _acceptAllAgreements
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
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
                            Icons.verified_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            busy ? 'Đang xử lý...' : 'Xác nhận và Ký cam kết',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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
            ),
          ],
        ],
      ),
    );
  }
}
