import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../auth/api.dart';
import 'partner_ui_kit.dart';

class RecruitmentOfficeVisit extends StatefulWidget {
  const RecruitmentOfficeVisit({super.key, required this.session});
  final Session session;

  @override
  State<RecruitmentOfficeVisit> createState() => _RecruitmentOfficeVisitState();
}

class _RecruitmentOfficeVisitState extends State<RecruitmentOfficeVisit> {
  List<dynamic> offices = [];
  bool checked = false;
  bool saved = false;
  bool busy = true;
  String? error;

  StreamSubscription<void>? _liveSubscription;
  @override
  void dispose() { _liveSubscription?.cancel(); super.dispose(); }
  @override
  void initState() {
    super.initState();
    _liveSubscription = widget.session.liveChanges.listen((_) { if (mounted) load(background: true); });
    load();
  }

  bool _fetching = false;
  Future<void> load({bool background = false}) async {
    if (_fetching || (background && busy)) return;
    _fetching = true;
    if (!background) setState(() => busy = true);
    try {
      final results = await Future.wait([
        widget.session.request('/partner/offices').catchError((_) => <dynamic>[]),
        widget.session.request('/partner/onboarding').catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      final onboarding = results[1] is Map ? results[1] as Map : {};
      final isConfirmed = onboarding['eligibility']?['office_visit_confirmed'] == true;
      setState(() {
        offices = results[0] is List ? results[0] as List : [];
        saved = isConfirmed;
        if (!background || isConfirmed) checked = isConfirmed;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      _fetching = false;
      if (mounted && !background) setState(() => busy = false);
    }
  }

  Future<void> confirm() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.request(
        '/partner/office-visit-confirmation',
        method: 'POST',
        body: {},
      );
      if (!mounted) return;
      setState(() {
        saved = true;
        checked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Đã xác nhận sẽ đến văn phòng thành công!'),
              ),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        title: const Text(
          'Địa chỉ văn phòng & Tiếp nhận',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: busy && offices.isEmpty && !saved
          ? const Center(
              child: CircularProgressIndicator(color: PartnerColors.primary),
            )
          : RefreshIndicator(
              onRefresh: load,
              color: PartnerColors.primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              error!,
                              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Hero Banner Card
                  _buildHeroCard(),

                  const SizedBox(height: 16),

                  // Checklist of items to bring
                  _buildPreparationCard(),

                  const SizedBox(height: 16),

                  // Office Locations Section
                  _buildOfficesSection(),

                  const SizedBox(height: 20),

                  // Commitment Checkbox & Action Button
                  _buildConfirmationCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
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
                alignment: Alignment.center,
                child: const Icon(
                  Icons.storefront_rounded,
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
                      'Văn phòng Tiếp nhận Đối tác',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Đối chiếu hồ sơ gốc & Trao trang bị đồng phục',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFDBEAFE),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Sau khi hoàn tất hồ sơ online và chọn đồng phục, bạn vui lòng đến văn phòng TaskLy gần nhất để chuyên viên đối chiếu giấy tờ và kích hoạt tài khoản.',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.schedule_rounded, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Giờ tiếp đón: 08:30 - 11:30 | 14:00 - 17:00 (Thứ 2 - Thứ 6)',
                    style: TextStyle(
                      fontSize: 11,
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

  Widget _buildPreparationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: Color(0xFF2563EB),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Hành trang cần chuẩn bị mang theo',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCheckItem(
            icon: Icons.badge_outlined,
            title: 'Bản gốc Căn cước công dân (CCCD)',
            desc: 'Còn hạn sử dụng, trùng khớp với ảnh chụp đã tải lên ứng dụng.',
            tag: 'Bắt buộc',
            tagColor: const Color(0xFFDC2626),
            tagBg: const Color(0xFFFEF2F2),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildCheckItem(
            icon: Icons.phone_android_rounded,
            title: 'Điện thoại đã cài app TaskLy Partner',
            desc: 'Dùng để quét mã QR check-in tiếp nhận tại quầy lễ tân.',
            tag: 'Cần thiết',
            tagColor: const Color(0xFF2563EB),
            tagBg: const Color(0xFFEFF6FF),
          ),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildCheckItem(
            icon: Icons.checkroom_outlined,
            title: 'Kiểm tra thông tin gói đồng phục',
            desc: 'Nhân viên sẽ đối chiếu số đo và bàn giao đúng gói trang bị đã đặt.',
            tag: 'Nhận tại quầy',
            tagColor: const Color(0xFF059669),
            tagBg: const Color(0xFFECFDF5),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem({
    required IconData icon,
    required String title,
    required String desc,
    required String tag,
    required Color tagColor,
    required Color tagBg,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF475569)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tagBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: tagColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
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
    );
  }

  Widget _buildOfficesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.location_on_rounded,
              color: Color(0xFF2563EB),
              size: 20,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Địa điểm văn phòng tiếp nhận',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (offices.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '${offices.length} địa điểm',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        if (offices.isEmpty)
          // Default Headquarters & Support Hub Card when no slots configured in DB
          Container(
            padding: const EdgeInsets.all(14),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.business_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Văn phòng TaskLy Partner Hub Trung Tâm',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place_rounded, size: 14, color: Color(0xFFEF4444)),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Tầng 6, Tòa nhà TaskLy Hub, 123 Đường Công Nghệ, Quận Cầu Giấy, Hà Nội',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.headset_mic_rounded, size: 12, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text(
                            'Hotline: 1900 6868',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          const ClipboardData(
                            text: 'Tầng 6, Tòa nhà TaskLy Hub, 123 Đường Công Nghệ, Quận Cầu Giấy, Hà Nội',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép địa chỉ văn phòng!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 12, color: Color(0xFF2563EB)),
                          SizedBox(width: 3),
                          Text(
                            'Sao chép',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          ...offices.map((office) {
            final name = office['name']?.toString() ?? 'Văn phòng tiếp nhận TaskLy';
            final address = office['address']?.toString() ?? 'Chưa cập nhật địa chỉ cụ thể';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.business_rounded,
                          color: Color(0xFF2563EB),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: address));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép địa chỉ vào bộ nhớ tạm!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 12, color: Color(0xFF2563EB)),
                        SizedBox(width: 3),
                        Text(
                          'Sao chép địa chỉ',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildConfirmationCard() {
    final canSubmit = !busy && !saved && checked;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: saved ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
          width: saved ? 1.5 : 1.0,
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
          if (saved) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bạn đã xác nhận sẽ đến văn phòng. Vui lòng đến đúng giờ hành chính để hoàn tất.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            InkWell(
              onTap: busy ? null : () => setState(() => checked = !checked),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: checked,
                        onChanged: busy
                            ? null
                            : (val) => setState(() => checked = val ?? false),
                        activeColor: PartnerColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Tôi đã xem địa chỉ và cam kết sẽ đến văn phòng TaskLy để đối chiếu hồ sơ gốc và nhận bàn giao trang bị.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: canSubmit ? confirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSubmit ? PartnerColors.primary : const Color(0xFFCBD5E1),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  disabledForegroundColor: const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  elevation: canSubmit ? 3 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
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
                    else ...[
                      const Icon(Icons.check_circle_outline_rounded, size: 18),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'Xác nhận sẽ đến văn phòng',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
