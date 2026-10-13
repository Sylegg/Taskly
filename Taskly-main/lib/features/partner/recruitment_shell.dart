import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';
import 'dart:convert';

import '../../auth/api.dart';
import '../../shared/vietnam_locations.dart';
import 'recruitment_exam.dart';
import 'recruitment_agreements.dart';
import 'recruitment_followup.dart';
import 'recruitment_uniform.dart';
import 'recruitment_final_documents.dart';
import 'recruitment_status_message.dart';
import 'recruitment_office_visit.dart';
import 'partner_account.dart';
import 'partner_benefits.dart';
import 'partner_jobs.dart';
import 'partner_inbox.dart';
import 'partner_notifications.dart';

import 'partner_ui_kit.dart';
import 'onboarding_completion.dart';

/// Authenticated Partner onboarding uses the existing Session and shared backend.
class RecruitmentShell extends StatefulWidget {
  const RecruitmentShell({super.key, required this.session, this.onLogout});
  final Session session;
  final Future<void> Function()? onLogout;
  @override
  State<RecruitmentShell> createState() => _RecruitmentShellState();
}

class _RecruitmentShellState extends State<RecruitmentShell>
    with WidgetsBindingObserver {
  Map<String, dynamic>? application;
  Map<String, dynamic>? identity;
  Map<String, dynamic>? examConfig;
  List<dynamic> areas = [], services = [];
  List<dynamic> notifications = [];
  final Set<String> _readNoticeIds = <String>{};
  List<dynamic> get bellNotifications => notifications.where((item) => item['channel'] == 'IN_APP').toList();
  int get unreadBellCount => bellNotifications
      .where((item) => item['read_at'] == null && !_readNoticeIds.contains((item['id'] ?? '').toString()))
      .length;

  Future<void> openNotifications() async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PartnerNotificationPage(
            session: widget.session,
            onNotificationRead: () async {
              try {
                final items =
                    await widget.session.request('/partner/notifications');
                if (mounted) setState(() => notifications = items as List);
              } catch (_) {}
            },
          ),
        ),
      );
      final items = await widget.session.request('/partner/notifications');
      if (mounted) setState(() => notifications = items as List);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tải được thông báo: $e')),
        );
      }
    }
  }
  Timer? polling;
  int pollSeconds = 30;
  int tab = 0;
  String? shownDecision;
  bool decisionDialogOpen = false;

  String decisionMessage(Map<String, dynamic> app) {
    final status = app['status'];
    final reason = (app['reason'] ?? '').toString();
    if (status == 'PRELIMINARY_APPROVED') return '$reason\n\nBạn cần hoàn tất chặng 3 (xác minh tại văn phòng và đồng phục), sau đó chặng 4 (thiết lập nhận việc và kích hoạt). Chỉ tài khoản đã kích hoạt mới nhận được việc.';
    if (status == 'REJECTED') return '$reason\n\nVui lòng đến trực tiếp phòng dịch vụ để được hướng dẫn xem xét hồ sơ. Mang CCCD gốc và các giấy tờ liên quan.\nĐịa chỉ kiểm thử: 123 Lê Minh Xuân\nHotline kiểm thử: 0900 000 000\nĐịa chỉ và hotline mẫu, cần thay trước khi vận hành thực tế.';
    if (status == 'ACTION_REQUIRED') return '$reason\n\nCác mục cần bổ sung: ${(app['requiredChanges'] as List? ?? []).join(', ')}\nMở hồ sơ để sửa các mục màu đỏ và gửi lại.';
    return '$reason\n\nHồ sơ đang được xem xét thêm. Hạn phản hồi: ${app['editableUntil'] == null ? 'Chưa có' : DateTime.parse(app['editableUntil']).toLocal()}';
  }

  Future<void> showDecisionNotice() async {
    if (!mounted || application == null || decisionDialogOpen) return;
    final app = application!;
    final status = app['status'].toString();
    if (!['PRELIMINARY_APPROVED', 'REJECTED', 'ACTION_REQUIRED', 'ESCALATED'].contains(status)) return;
    final signature = '${app['id']}:$status:${app['reason']}:${app['editableUntil']}';
    if (signature == shownDecision) return;
    shownDecision = signature;
    decisionDialogOpen = true;
    final proceed = await showDialog<bool>(context: context, barrierDismissible: false, builder: (context) => AlertDialog(
      title: Text(_statusLabel(status)),
      content: SingleChildScrollView(child: Text(decisionMessage(app))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Đã hiểu')),
        if (['PRELIMINARY_APPROVED', 'ACTION_REQUIRED'].contains(status)) FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(status == 'ACTION_REQUIRED' ? 'Bổ sung hồ sơ' : 'Tiếp tục chặng 3'))],
    ));
    decisionDialogOpen = false;
    if (!mounted || proceed != true) return;
    if (status == 'ACTION_REQUIRED') { await register(); }
    else { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecruitmentFollowup(session: widget.session))); await load(); }
  }
  bool busy = false;
  bool loading = false;
  String? error;
  StreamSubscription<void>? _liveSubscription;
  @override
  void initState() {
    super.initState();
    _liveSubscription = widget.session.liveChanges.listen((_) { if (mounted) load(background: true); });
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    polling?.cancel();
    _liveSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      load(background: true);
    } else {
      polling?.cancel();
    }
  }

  Future<void> load({bool background = false}) async {
    if (!mounted || loading) return;
    loading = true;
    polling?.cancel();
    if (!background) {
      setState(() {
        busy = true;
        error = null;
      });
    }
    try {
      final results = await Future.wait([
        widget.session.request('/partner/onboarding'),
        widget.session.request('/partner/recruitment-areas'),
        widget.session.request('/public/services'),
        widget.session.request('/partner/notifications'),
        widget.session.request('/verifications/me').catchError((_) => null),
        widget.session.request('/partner/exam').catchError((_) => null),
      ]);
      if (!mounted) return;
      final changed =
          jsonEncode(application) != jsonEncode(results[0]) ||
          jsonEncode(identity) != jsonEncode(results[4]) ||
          jsonEncode(examConfig) != jsonEncode(results[5]) ||
          jsonEncode(areas) != jsonEncode(results[1]) ||
          jsonEncode(services) != jsonEncode(results[2]['services'] ?? []) ||
          jsonEncode(notifications) != jsonEncode(results[3]);
      if (changed || error != null) {
        setState(() {
          application = Map<String, dynamic>.from(results[0]);
          identity = results[4] == null
              ? null
              : Map<String, dynamic>.from(results[4]);
          examConfig = results[5] == null
              ? null
              : Map<String, dynamic>.from(results[5]);
          areas = results[1] as List;
          services = (results[2]['services'] ?? []) as List;
          notifications = results[3] as List;
          error = null;
        });
      }
      pollSeconds = 30;
      WidgetsBinding.instance.addPostFrameCallback((_) { unawaited(showDecisionNotice()); });
    } catch (e) {
      if (mounted) {
        if (!background || application == null) {
          setState(() => error = e.toString());
        }
        pollSeconds = (pollSeconds * 2).clamp(30, 120);
      }
    } finally {
      loading = false;
      if (mounted) {
        if (!background) setState(() => busy = false);
        if (WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          polling = Timer(
            Duration(seconds: pollSeconds),
            () => load(background: true),
          );
        }
      }
    }
  }

  Future<void> register() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _Registration(
          session: widget.session,
          application: application!,
          areas: areas,
          services: services,
          readOnly: application!['status'] != 'ACTION_REQUIRED' && onboardingMissing(
            application!,
            identity: identity,
          )[1]!.isEmpty,
        ),
      ),
    );
    if (result == true) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFDCEAFF), Color(0xFFF6FAFF)],
              ),
              border: Border.all(color: const Color(0xFFD4E2FF)),
            ),
            alignment: Alignment.center,
            child: const Text(
              'T',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF245AD3),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ['Công việc', 'Hoạt động', 'Thu nhập', 'Tài khoản'][tab],
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                    color: PartnerColors.navy,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'TaskLy Partner',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: PartnerColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (tab == 1)
          TextButton(
            onPressed: () => openPartnerJobHistory(context, widget.session),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF00B14F)),
            child: const Text('Lịch sử'),
          ),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: openNotifications,
          icon: Badge(
            isLabelVisible: unreadBellCount > 0,
            label: Text(
              '$unreadBellCount',
            ),
            backgroundColor: PartnerColors.primary,
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
          children: [
            if (error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF9CED5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFCE4C55)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        error!,
                        semanticsLabel: 'Lỗi tải hồ sơ',
                        style: const TextStyle(
                          color: Color(0xFFAF4657),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    TextButton(onPressed: load, child: const Text('Thử lại')),
                  ],
                ),
              ),
            if (application != null) ...content(),
          ],
        ),
      ),
    ),
    bottomNavigationBar: PartnerFloatingPillNavBar(
      selectedIndex: tab,
      onDestinationSelected: (value) => setState(() => tab = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.work_outline),
          selectedIcon: Icon(Icons.work_rounded),
          label: 'Công việc',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: 'Hoạt động',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet_rounded),
          label: 'Thu nhập',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Tài khoản',
        ),
      ],
    ),
  );

  Future<void> _openStep(int stepNumber) async {
    if (stepNumber == 8) { if (['APPROVED', 'FINAL_REVIEW'].contains(application?['status'])) { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecruitmentFinalDocuments(session: widget.session, readOnly: application?['status'] == 'FINAL_REVIEW'))); await load(); } return; }
    if (stepNumber == 8 && !canOpenOnboardingStage(4, onboardingMissing(application!, identity: identity))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chặng 3 chưa hoàn tất. Vui lòng hoàn tất các mục đang báo đỏ trước khi sang chặng 4.')));
      return;
    }
    if (stepNumber == 4) {
      try {
        final latest = await widget.session.request('/partner/exam');
        if (!mounted) return;
        setState(() => examConfig = Map<String, dynamic>.from(latest));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tải được quy chế bài thi: $e')),
        );
        return;
      }
    }
    await _showStepDetailBottomSheet(stepNumber);
  }

  Future<void> _showStepDetailBottomSheet(int stepNumber) async {
    final currentStatus = application?['status']?.toString() ?? 'REGISTERED';
    final currentSubStep = _subStepOf(currentStatus);
    final isFullyActive = currentStatus == 'ACTIVE';
    final isStepDone = onboardingMissing(
      application!,
      identity: identity,
    )[stepNumber]!.isEmpty;
    final isStepCurrent = !isStepDone && currentSubStep >= stepNumber;

    final (
      String stepTitle,
      String stageName,
      IconData stepIcon,
      String stepDescription,
      List<String> requirements,
      String actionLabel,
      Color accentColor,
    ) = switch (stepNumber) {
      1 => (
        'Bước 1: Thông tin cá nhân & Hồ sơ',
        'Chặng 2: Nộp hồ sơ & Cam kết',
        Icons.badge_rounded,
        'Hoàn tất thông tin định danh cá nhân, nhập số CCCD và tải ảnh CCCD 2 mặt kèm ảnh chân dung trực diện để xác thực danh tính.',
        [
          'Họ và tên, số điện thoại, ngày tháng năm sinh chính xác',
          'Số CCCD 12 chữ số hợp lệ do cơ quan công an cấp',
          'Tải lên 03 ảnh rõ nét: CCCD mặt trước, CCCD mặt sau, Ảnh chân dung',
          'Chọn khu vực hoạt động (Tỉnh/thành phố và quận/huyện)',
        ],
        'Chỉnh sửa hồ sơ',
        const Color(0xFF2563EB),
      ),
      2 => (
        'Ký cam kết tiêu chuẩn dịch vụ',
        'Chặng 2: Nộp hồ sơ & Cam kết',
        Icons.edit_document,
        'Đọc và ký chấp thuận toàn bộ các quy tắc ứng xử, cam kết bảo vệ tài sản khách hàng, chính sách an toàn và bảo mật dữ liệu của TaskLy.',
        [
          'Quy tắc ứng xử và tiêu chuẩn văn hóa dịch vụ (v2.0)',
          'Chính sách an toàn lao động & bảo vệ tài sản khách hàng',
          'Thỏa thuận hợp tác đối tác TaskLy Partner chính thức',
          'Chính sách bảo mật dữ liệu và thông tin người dùng',
          'Cam kết minh bạch giá và quy chế sử dụng đồng phục',
        ],
        'Đọc & Ký cam kết dịch vụ',
        const Color(0xFF2563EB),
      ),
      4 => (
        'Hoàn thành bài kiểm tra 20 câu',
        'Chặng 1: Kiểm tra kiến thức',
        Icons.assignment_turned_in_rounded,
        'Vượt qua bài thi trắc nghiệm lý thuyết trực tuyến 20 câu hỏi về nghiệp vụ và quy chế hoạt động. Đạt tối thiểu ${examConfig?['pass_mark']}/20 câu để qua bài thi.',
        [
          'Cấu trúc: 20 câu trắc nghiệm về nghiệp vụ và quy định TaskLy',
          'Thời gian làm bài: ${examConfig?['exam_minutes']} phút',
          'Tiêu chuẩn đạt: Đúng tối thiểu ${examConfig?['pass_mark']}/20 câu',
          'Hệ thống chấm điểm và công bố kết quả ngay lập tức',
        ],
        'Bắt đầu',
        const Color(0xFF7C3AED),
      ),
      5 => (
        'Hệ thống duyệt hồ sơ sơ bộ',
        'Chặng 3: Xác minh & Nhận đồng phục',
        Icons.verified_user_rounded,
        'Ban tuyển dụng TaskLy thẩm định tính hợp lệ của thông tin CCCD, kết quả bài thi kiểm tra và nhu cầu mở tuyển tại khu vực bạn đăng ký.',
        [
          'Đối chiếu tính xác thực thông tin định danh và ảnh CCCD',
          'Kiểm tra kết quả bài thi 20 câu đạt chuẩn',
          'Cam kết thời gian thẩm định (SLA): 24h - 48h làm việc',
          'Nhận thông báo phê duyệt sơ bộ ngay trên ứng dụng',
        ],
        'Theo dõi tiến độ thẩm định',
        const Color(0xFF0D9488),
      ),
      6 => (
        'Xem địa chỉ & Xác nhận đến văn phòng',
        'Chặng 3: Xác minh & Nhận đồng phục',
        Icons.store_rounded,
        'Sau khi chọn đồng phục, xem địa chỉ và tick xác nhận sẽ đến văn phòng. Mang CCCD gốc để nhân viên đối chiếu và bàn giao đồng phục.',
        [
          'Mang theo CCCD/Hộ chiếu bản gốc còn nguyên vẹn, còn hạn',
          'Xem địa chỉ văn phòng và tick xác nhận sẽ đến',
          'Chuyên viên đối chiếu và trao biên nhận hồ sơ hợp lệ',
          'Hoàn tất xác minh trực tiếp để kích hoạt tài khoản',
        ],
        'Xem địa chỉ & Xác nhận',
        const Color(0xFF0D9488),
      ),
      7 => (
        'Chọn đồng phục TaskLy',
        'Chặng 3: Xác minh & Nhận đồng phục',
        Icons.checkroom_rounded,
        'Lựa chọn kích cỡ trang phục, đăng ký nhận đồng phục chính hãng TaskLy (áo polo, mũ bảo hiểm, túi/tạp dề đồ nghề chuyên dụng).',
        [
          'Chọn kích cỡ áo polo phù hợp (S, M, L, XL, XXL)',
          'Nhận 02 áo polo cao cấp có gắn logo thương hiệu TaskLy',
          'Nhận 01 nón bảo hiểm đạt chuẩn an toàn giao thông',
          'Nhận túi đồ nghề và hướng dẫn nhận đơn đầu tiên',
        ],
        'Chọn đồng phục',
        const Color(0xFF0D9488),
      ),
      8 => (
        'Kích hoạt tài khoản và nhận việc',
        'Chặng 4: Sẵn sàng nhận việc',
        Icons.rocket_launch_rounded,
        'Hồ sơ của bạn đã hoàn tất xuất sắc! Tài khoản sẵn sàng hoạt động để bạn bật trực tuyến và bắt đầu gia tăng thu nhập với TaskLy.',
        [
          'Tài khoản đối tác chính thức được kích hoạt',
          'Bật chế độ TRỰC TUYẾN trên ứng dụng để nhận việc',
          'Thu nhập minh bạch, nhận tiền ngay sau mỗi cuốc hoàn thành',
          'Đội ngũ hỗ trợ đối tác đồng hành 24/7 trong suốt quá trình',
        ],
        isFullyActive ? 'Đến mục Công việc ngay' : 'Sẵn sàng kích hoạt',
        const Color(0xFF16A34A),
      ),
      _ => (
        'Chi tiết quy trình',
        'Lộ trình Tasker',
        Icons.info_outline_rounded,
        'Hoàn tất đăng ký để gia nhập mạng lưới đối tác TaskLy.',
        <String>[],
        'Thực hiện ngay',
        const Color(0xFF2563EB),
      ),
    };

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final fullName = (application?['fullName'] ?? '').toString().trim();
        final contactPhone = (application?['contactPhone'] ?? '')
            .toString()
            .trim();
        final cccd =
            (identity?['documentNumber'] ??
                    application?['identityCardNumber'] ??
                    '')
                .toString()
                .trim();
        final dobStr = (application?['dateOfBirth'] ?? '').toString().trim();
        final selectedAreaNames = (application?['areaIds'] as List? ?? []).map((
          aid,
        ) {
          final match = areas.firstWhere(
            (a) => a['id'] == aid,
            orElse: () => null,
          );
          return match != null
              ? '${match['city']} · ${match['name']}'
              : aid.toString();
        }).toList();

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. DRAG HANDLE & TOP BAR
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(stepIcon, color: accentColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stageName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            stepTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // 2. SCROLLABLE BODY
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // STATUS BADGE CARD
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isStepDone
                              ? const Color(0xFFF0FDF4)
                              : isStepCurrent
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isStepDone
                                ? const Color(0xFFBBF7D0)
                                : isStepCurrent
                                ? const Color(0xFFFECACA)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isStepDone
                                  ? Icons.check_circle_rounded
                                  : isStepCurrent
                                  ? Icons.warning_amber_rounded
                                  : Icons.lock_outline_rounded,
                              size: 18,
                              color: isStepDone
                                  ? const Color(0xFF16A34A)
                                  : isStepCurrent
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isStepDone
                                    ? 'Trạng thái: ĐÃ HOÀN TẤT BƯỚC NÀY'
                                    : isStepCurrent
                                    ? 'Chưa hoàn tất • Cần bổ sung: ${onboardingMissing(application!, identity: identity)[stepNumber]!.join(' ')}'
                                    : 'Trạng thái: CHỜ MỞ (Cần hoàn thành chặng trước)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isStepDone
                                      ? const Color(0xFF15803D)
                                      : isStepCurrent
                                      ? const Color(0xFFB91C1C)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // DESCRIPTION
                      Text(
                        stepDescription,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // REQUIREMENTS CHECKLIST
                      const Text(
                        'Đầu việc & Tiêu chuẩn cần hoàn thành',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: requirements.map((req) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 16,
                                    color: Color(0xFF0B9879),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      req,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF475569),
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // YOUR PROFILE DATA SECTION
                      const Text(
                        'Thông tin hồ sơ liên quan của bạn',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            if (stepNumber == 1) ...[
                              _buildInfoRow(
                                'Họ và tên',
                                fullName.isNotEmpty
                                    ? fullName
                                    : 'Chưa cập nhật',
                              ),
                              _buildInfoRow(
                                'Số điện thoại',
                                contactPhone.isNotEmpty
                                    ? contactPhone
                                    : 'Chưa cập nhật',
                              ),
                              _buildInfoRow(
                                'Số CCCD',
                                cccd.isNotEmpty ? cccd : 'Chưa có',
                              ),
                              _buildInfoRow(
                                'Ngày sinh',
                                dobStr.isNotEmpty ? dobStr : 'Chưa cập nhật',
                              ),
                              _buildInfoRow(
                                'Khu vực hoạt động',
                                selectedAreaNames.isNotEmpty
                                    ? '${selectedAreaNames.take(2).join(', ')}${selectedAreaNames.length > 2 ? ', …' : ''}'
                                    : 'Chưa chọn khu vực',
                                singleLine: true,
                              ),
                              _buildInfoRow(
                                'Ảnh KYC (3 ảnh)',
                                '${savedIdentitySides(identity).length}/3 ảnh đã lưu trên hệ thống',
                              ),
                            ] else if (stepNumber == 2) ...[
                              _buildInfoRow(
                                'Số văn bản cam kết',
                                '05 văn bản tiêu chuẩn',
                              ),
                              _buildInfoRow(
                                'Phiên bản quy chế',
                                'v2.1 mới nhất',
                              ),
                              _buildInfoRow(
                                'Trạng thái xác nhận',
                                isStepDone
                                    ? 'Đã ký chấp thuận'
                                    : 'Chưa ký xác nhận',
                              ),
                            ] else if (stepNumber == 3) ...[
                              _buildInfoRow(
                                'Học viện đào tạo',
                                'Partner Academy Online',
                              ),
                              _buildInfoRow(
                                'Số lượng bài học',
                                '04 bài học nghiệp vụ chuẩn',
                              ),
                              _buildInfoRow(
                                'Hình thức',
                                'Video tương tác trực tuyến',
                              ),
                            ] else if (stepNumber == 4) ...[
                              _buildInfoRow(
                                'Quy mô bài thi',
                                '20 câu trắc nghiệm nghiệp vụ',
                              ),
                              _buildInfoRow(
                                'Điểm chuẩn đạt',
                                '${examConfig?['pass_mark']}/20 câu',
                              ),
                              _buildInfoRow(
                                'Thời gian làm bài',
                                '${examConfig?['exam_minutes']} phút',
                              ),
                            ] else if (stepNumber == 5) ...[
                              _buildInfoRow(
                                'Đơn vị thẩm định',
                                'Phòng Tuyển dụng & Đảm bảo TaskLy',
                              ),
                              _buildInfoRow(
                                'Thời gian phản hồi',
                                'SLA 24h - 48h làm việc',
                              ),
                              _buildInfoRow(
                                'Trạng thái hiện tại',
                                _statusLabel(currentStatus),
                              ),
                            ] else if (stepNumber == 6) ...[
                              _buildInfoRow(
                                'Địa điểm đối chiếu',
                                'TaskLy Partner Hub',
                              ),
                              _buildInfoRow(
                                'Giấy tờ cần mang',
                                'Bản gốc CCCD/Hộ chiếu hợp lệ',
                              ),
                              _buildInfoRow(
                                'Khung giờ tiếp nhận',
                                '08:30 - 11:30 & 14:00 - 17:00',
                              ),
                            ] else if (stepNumber == 7) ...[
                              _buildInfoRow(
                                'Trang bị bàn giao',
                                '02 áo polo, 01 nón bảo hiểm, túi đồ nghề',
                              ),
                              _buildInfoRow(
                                'Kích cỡ hỗ trợ',
                                'Size S, M, L, XL, XXL',
                              ),
                              _buildInfoRow(
                                'Địa điểm nhận',
                                'Văn phòng TaskLy Partner Hub',
                              ),
                            ] else ...[
                              _buildInfoRow(
                                'Trạng thái tài khoản',
                                isFullyActive
                                    ? 'ĐÃ KÍCH HOẠT CHÍNH THỨC'
                                    : 'Chờ hoàn tất hồ sơ',
                              ),
                              _buildInfoRow(
                                'Chế độ nhận đơn',
                                isFullyActive
                                    ? 'Sẵn sàng trực tuyến'
                                    : 'Tạm khóa nhận việc',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. ACTION BUTTONS
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text(
                          'Đóng',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          isStepDone
                              ? Icons.visibility_outlined
                              : Icons.arrow_forward_rounded,
                          size: 18,
                        ),
                        label: Text(
                          isStepDone
                              ? (stepNumber == 1
                                    ? 'Xem hồ sơ'
                                    : stepNumber == 2
                                    ? 'Xem cam kết'
                                    : stepNumber == 4
                                    ? 'Xem / Thi lại'
                                    : stepNumber == 7
                                    ? 'Xem đồng phục đã đặt'
                                    : 'Đóng')
                              : actionLabel,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _executeStepAction(stepNumber);
                        },
                      ),
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

  Widget _buildInfoRow(String label, String value, {bool singleLine = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: singleLine ? 1 : null,
              overflow: singleLine ? TextOverflow.ellipsis : null,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeStepAction(int stepNumber) async {
    if (stepNumber == 8) { if (['APPROVED', 'FINAL_REVIEW'].contains(application?['status'])) { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecruitmentFinalDocuments(session: widget.session, readOnly: application?['status'] == 'FINAL_REVIEW'))); await load(); } return; }
    if (stepNumber == 8 && !canOpenOnboardingStage(4, onboardingMissing(application!, identity: identity))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hoàn tất chặng 3 trước khi sang chặng 4.')));
      return;
    }
    if (stepNumber != 1 &&
        stepNumber != 2 &&
        stepNumber != 4 &&
        stepNumber != 7 &&
        onboardingMissing(
          application!,
          identity: identity,
        )[stepNumber]!.isEmpty) {
      return;
    }
    switch (stepNumber) {
      case 1:
        await register();
        break;
      case 2:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecruitmentAgreements(session: widget.session),
          ),
        );
        await load();
        break;
      case 4:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecruitmentExam(session: widget.session),
          ),
        );
        await load();
        break;
      case 5:
      case 6:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecruitmentOfficeVisit(session: widget.session),
          ),
        );
        await load();
        break;
      case 7:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecruitmentUniform(session: widget.session, ordersOnly: onboardingMissing(application!, identity: identity)[7]!.isEmpty),
          ),
        );
        await load();
        break;
      case 8:
        final currentStatus =
            application?['status']?.toString() ?? 'REGISTERED';
        final isApproved = currentStatus == 'ACTIVE' ||
            currentStatus == 'APPROVED' ||
            (application?['eligibility']?['final_approved'] == true);
        if (isApproved) {
          setState(() => tab = 0);
        } else {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RecruitmentFollowup(session: widget.session),
            ),
          );
          await load();
        }
        break;
    }
  }

  int _subStepOf(String status) {
    return switch (status) {
      'REGISTERED' || 'WAITLISTED' || 'PROFILE_INCOMPLETE' => 1,
      'AGREEMENT_REQUIRED' => 2,
      'TRAINING_REQUIRED' => 3,
      'EXAM_REQUIRED' || 'EXAM_IN_PROGRESS' || 'EXAM_FAILED' || 'EXPIRED' => 4,
      'PRELIMINARY_REVIEW' || 'ACTION_REQUIRED' || 'ESCALATED' => 5,
      'PRELIMINARY_APPROVED' || 'UNIFORM_PENDING' || 'DOCUMENT_APPOINTMENT' => application?['eligibility']?['uniform_ordered'] == true ? 6 : 7,
      'DOCUMENTS_RECEIVED' || 'FINAL_REVIEW' => 6,
      'APPROVED' || 'ACTIVE' => 8,
      _ => 1,
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'REGISTERED' => 'Vừa đăng ký',
      'EXAM_REQUIRED' || 'EXAM_IN_PROGRESS' => 'Chờ thi đầu vào',
      'EXAM_FAILED' || 'EXPIRED' => 'Chưa đạt bài thi',
      'TRAINING_REQUIRED' => 'Đang đào tạo',
      'PROFILE_INCOMPLETE' => 'Chưa hoàn thiện hồ sơ',
      'PRELIMINARY_REVIEW' => 'Chờ duyệt sơ bộ',
      'ESCALATED' => 'Đang xem xét thêm',
      'ACTION_REQUIRED' => 'Cần bổ sung',
      'PRELIMINARY_APPROVED' => 'Đã duyệt sơ bộ',
      'UNIFORM_PENDING' => 'Chọn đồng phục',
      'DOCUMENT_APPOINTMENT' => 'Hẹn nộp hồ sơ',
      'DOCUMENTS_RECEIVED' => 'Đã tiếp nhận hồ sơ',
      'FINAL_REVIEW' => 'Chờ duyệt cuối',
      'APPROVED' => 'Đã được duyệt',
      'ACTIVE' => 'Đang hoạt động',
      'REJECTED' => 'Bị từ chối',
      'SUSPENDED' => 'Tạm ngưng',
      'WAITLISTED' => 'Danh sách chờ',
      _ => status,
    };
  }

  List<Widget> content() {
    final status = application!['status'] as String;
    if (tab == 1) {
      return [PartnerInbox(session: widget.session)];
    }
    if (tab == 2) {
      return [PartnerBenefits(session: widget.session)];
    }
    if (tab == 3) {
      return [
        PartnerAccount(session: widget.session, onLogout: widget.onLogout),
      ];
    }

    // TAB 0: CÔNG VIỆC / RECRUITMENT STUDIO JOURNEY
    final fullName = (application!['fullName'] ?? '').toString().trim();
    final name = fullName.isNotEmpty ? fullName : 'Tasker tương lai';
    final subStep = _subStepOf(status);
    final missing = onboardingMissing(application!, identity: identity);
    final stage = firstIncompleteOnboardingStage(missing);
    if (status == 'ACTIVE') {
      return [PartnerJobs(session: widget.session, application: application)];
    }

    final isAgreementsDone = (missing[2]?.isEmpty == true) ||
        (application!['eligibility']?['agreements_current'] == true);
    final isPreliminaryApproved = (missing[5]?.isEmpty == true) ||
        (application!['eligibility']?['preliminary_approved'] == true);
    final isAwaitingReview = (isAgreementsDone && !isPreliminaryApproved) ||
        status == 'UNDER_REVIEW' ||
        status == 'SUBMITTED';

    return [
      // 1. HERO CARD (HTML STYLE)
      PartnerHeroWidget(
        name: name,
        currentStep: stage,
        totalSteps: isPreliminaryApproved ? 4 : 2,
        stepLabel: status == 'ACTIVE'
            ? 'Hoàn tất 4 chặng'
            : isPreliminaryApproved
                ? 'Chặng $stage/4'
                : 'Chặng ${stage <= 2 ? stage : 2}/2',
        isActive: status == 'ACTIVE',
      ),
      const SizedBox(height: 12),

      // THÔNG BÁO XÉT DUYỆT 24H (Khi đã cam kết xong hoặc đang ở chặng 2/3)
      if (['ESCALATED', 'REJECTED', 'ACTION_REQUIRED'].contains(status)) ...[
        PartnerItemTile(
          emoji: status == 'REJECTED' ? 'ℹ️' : '📋',
          title: _statusLabel(status),
          subtitle: decisionMessage(application!),
        ),
        const SizedBox(height: 12),
      ],
      if (status == 'ACTION_REQUIRED') Partner3DButton(label: 'Bổ sung hồ sơ thiếu', onPressed: busy ? null : register),
      if (!['ESCALATED', 'REJECTED', 'ACTION_REQUIRED'].contains(status) && (isAwaitingReview || isAgreementsDone || stage == 2 || stage == 3)) ...[
        _buildReviewNoticeCard(
          isAgreementsDone: isAgreementsDone,
          isAwaitingReview: isAwaitingReview,
        ),
        const SizedBox(height: 6),
      ],

      // Extra shortcuts if applicant can do auxiliary actions
      if (status == 'REGISTERED' || status == 'DRAFT') ...[
        const SizedBox(height: 10),
        Partner3DButton(
          label: 'Hoàn thiện đăng ký',
          onPressed: busy ? null : register,
        ),
      ],
      // 3. LỘ TRÌNH CỦA BẠN (Matches test: expect(find.text('Đăng ký trở thành Tasker'), findsOneWidget))
      PartnerSectionTitle(
        'Đăng ký trở thành Tasker',
        trailing: PartnerPillBadge(
          text: isPreliminaryApproved ? 'Chặng 3 - 4' : 'Chặng 1 - 2',
          type: 'blue',
        ),
      ),
      PartnerJourneyTimeline(
        examPassMark: examConfig?['pass_mark'] as int?,
        currentStep: subStep,
        missingRequirements: missing,
        isFullyActive: status == 'ACTIVE',
        status: status,
        isStage2Approved: isPreliminaryApproved,
        onTapAction: (stepNumber) async {
          await _openStep(stepNumber);
        },
      ),
    ];
  }

  Widget _buildReviewNoticeCard({
    required bool isAgreementsDone,
    required bool isAwaitingReview,
  }) {
    final app = application;
    final status = app?['status']?.toString() ?? '';
    final approved = app?['eligibility']?['preliminary_approved'] == true;
    if (approved || ['ACTION_REQUIRED', 'REJECTED', 'ESCALATED', 'SUSPENDED'].contains(status)) {
      final (title, message) = recruitmentStatusMessage(app!);
      return Container(
        margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFD1FAE5))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8), Text(message),
        ]),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFDE68A),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C1E5BF8),
            blurRadius: 14,
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFDE68A),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAgreementsDone
                          ? 'Thông báo xét duyệt hồ sơ'
                          : 'Cam kết đối tác & Xét duyệt',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: PartnerColors.navy,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAgreementsDone
                          ? 'Đã gửi cam kết · Khoảng 24 giờ'
                          : 'Quy trình xét duyệt hồ sơ',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFDE68A),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 13,
                      color: Color(0xFFD97706),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '24h xét duyệt',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFDE68A),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_rounded,
                  size: 18,
                  color: Color(0xFFD97706),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trong khoảng 24 giờ, đơn hồ sơ của bạn sẽ được quản lý xét duyệt và chuyển qua chặng 3.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isAgreementsDone
                        ? 'Hệ thống đang xử lý thẩm định hồ sơ của bạn.'
                        : 'Sau khi ký cam kết, ban quản lý sẽ phản hồi kết quả trong 24 giờ.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _openStep(2),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    isAgreementsDone ? 'Xem lại cam kết' : 'Ký ngay',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: PartnerColors.primary,
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
}

class _Registration extends StatefulWidget {
  const _Registration({
    required this.session,
    required this.application,
    required this.areas,
    required this.services,
    this.readOnly = false,
  });
  final bool readOnly;
  final Session session;
  final Map<String, dynamic> application;
  final List<dynamic> areas, services;
  @override
  State<_Registration> createState() => _RegistrationState();
}

class _RegistrationState extends State<_Registration> {
  List<String> get requestedChanges => widget.application['status'] == 'ACTION_REQUIRED' ? List<String>.from(widget.application['requiredChanges'] ?? []) : [];
  bool needsCorrection(String label) => requestedChanges.any((item) {
    final a = item.toLowerCase(); final b = label.toLowerCase();
    return a == b || (b == 'số cccd / mã định danh (12 số)' && a == 'số cccd / mã định danh') || (b == 'điện thoại liên hệ' && a == 'số điện thoại liên hệ');
  });
  bool canEdit(String label) => !widget.readOnly && (requestedChanges.isEmpty || needsCorrection(label));
  String sideLabel(String side) => side == 'FRONT' ? 'Ảnh CCCD mặt trước' : side == 'BACK' ? 'Ảnh CCCD mặt sau' : 'Ảnh chân dung';
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.application['fullName']);
  late final phone = TextEditingController(
    text: widget.application['contactPhone'] ?? '',
  );
  late final dob = TextEditingController(
    text: widget.application['dateOfBirth'] ?? '',
  );
  int? dobDay;
  int? dobMonth;
  int? dobYear;
  late final cccdNumber = TextEditingController(
    text:
        (widget.application['identityNumber'] ??
                widget.application['documentNumber'] ??
                '')
            .toString(),
  );
  bool frontImageUploaded = false;
  bool backImageUploaded = false;
  bool portraitImageUploaded = false;
  final previews = <String, Uint8List>{};
  final imageUrls = <String, String>{};
  bool uploadingIdentity = false;
  Map<String, dynamic>? verification;
  late List<String> areaIds = List<String>.from(widget.application['areaIds']);
  late List<String> serviceIds = List<String>.from(
    widget.application['serviceIds'],
  );
  late int version = widget.application['version'];
  int step = 0;
  bool busy = false;
  bool _canLeave = false;
  String? error;

  late List<Map<String, dynamic>> allAvailableAreas;
  String selectedRegion = 'Tất cả';
  String? selectedCity;
  String areaSearchQuery = '';
  final searchCtrl = TextEditingController();
  bool showAllAreas = false;

  @override
  void initState() {
    super.initState();
    allAvailableAreas = VietnamLocations.getAllAreas(
      backendAreas: widget.areas,
    );
    if (widget.application['firstSubmittedAt'] == null) {
      final availableIds = allAvailableAreas
          .map((a) => a['id'].toString())
          .toSet();
      areaIds.removeWhere((id) => !availableIds.contains(id));
    }
    if (allAvailableAreas.isNotEmpty) {
      final firstMatch = allAvailableAreas.firstWhere(
        (a) => areaIds.contains(a['id']),
        orElse: () => allAvailableAreas.first,
      );
      selectedCity = firstMatch['city']?.toString();
    }

    if (serviceIds.isEmpty && widget.services.isNotEmpty) {
      serviceIds = widget.services.map((s) => s['id'].toString()).toList();
    }

    final initialDob = widget.application['dateOfBirth'];
    if (initialDob is String && initialDob.isNotEmpty) {
      final parts = initialDob.split('-');
      if (parts.length == 3) {
        dobYear = int.tryParse(parts[0]);
        dobMonth = int.tryParse(parts[1]);
        dobDay = int.tryParse(parts[2]);
      }
    }
    _syncDob();
    _loadIdentityImages();
  }

  void _syncDob() {
    if (dobYear != null && dobMonth != null && dobDay != null) {
      dob.text =
          '${dobYear!.toString().padLeft(4, '0')}-${dobMonth!.toString().padLeft(2, '0')}-${dobDay!.toString().padLeft(2, '0')}';
    } else {
      dob.text = '';
    }
  }

  String? _validateDob() {
    if (dob.text.isEmpty ||
        dobYear == null ||
        dobMonth == null ||
        dobDay == null) {
      return 'Vui lòng chọn đầy đủ ngày, tháng và năm sinh';
    }
    final parsed = DateTime.tryParse(dob.text);
    if (parsed == null) return 'Ngày sinh không hợp lệ';
    final now = DateTime.now();
    final adultCutoff = DateTime(now.year - 18, now.month, now.day);
    if (parsed.isAfter(adultCutoff)) {
      return 'Đối tác phải từ đủ 18 tuổi trở lên';
    }
    return null;
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    dob.dispose();
    cccdNumber.dispose();
    previews.clear();
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> save({
    bool submit = false,
    bool advance = false,
    bool personalOnly = false,
  }) async {
    if (busy || uploadingIdentity) return;
    if (widget.readOnly) {
      if (advance && step < 2) {
        setState(() => step++);
      } else {
        Navigator.pop(context);
      }
      return;
    }
    if (!personalOnly && (step >= 1 || submit) && areaIds.isEmpty) {
      setState(() => error = 'Vui lòng tick chọn ít nhất 1 khu vực làm việc.');
      return;
    }
    if (advance && (!form.currentState!.validate() || _validateDob() != null)) {
      setState(
        () => error =
            _validateDob() ?? 'Vui lòng điền đầy đủ thông tin cá nhân hợp lệ.',
      );
      return;
    }
    if (areaIds.isNotEmpty &&
        serviceIds.isEmpty &&
        widget.services.isNotEmpty) {
      serviceIds = widget.services.map((s) => s['id'].toString()).toList();
    }
    if (submit &&
        (!form.currentState!.validate() ||
            areaIds.isEmpty ||
            serviceIds.isEmpty)) {
      setState(
        () =>
            error = 'Điền thông tin và chọn ít nhất một khu vực, một dịch vụ.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final saved = await widget.session.request(
        '/partner/onboarding',
        method: 'PUT',
        body: {
          'version': version,
          'fullName': name.text,
          'contactPhone': phone.text,
          'dateOfBirth': dob.text.isEmpty ? null : dob.text,
          'areaIds': areaIds,
          'serviceIds': serviceIds,
          'experience': widget.application['experience'] ?? '',
          'transport': widget.application['transport'] ?? '',
          'referral': widget.application['referral'] ?? '',
        },
      );
      version = saved['version'];
      if (!personalOnly || cccdNumber.text.trim().isNotEmpty) {
        await _saveIdentityDraft(submit: submit);
      }
      unawaited(
        widget.session.syncUser().catchError((Object error) {
          debugPrint(
            'Could not refresh account after registration save: $error',
          );
        }),
      );
      if (submit && widget.application['status'] != 'PRELIMINARY_REVIEW') {
        await widget.session.request(
          widget.application['status'] == 'ACTION_REQUIRED'
              ? '/partner/kyc/submit'
              : '/partner/onboarding/submit',
          method: 'POST',
          body: {
            'version': version,
            'requestId': 'registration-${saved['id']}-$version',
          },
        );
      }
      if (mounted) {
        if (advance) {
          setState(() => step++);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                personalOnly
                    ? 'Đã lưu thông tin cá nhân vào hồ sơ.'
                    : 'Đã lưu hồ sơ.',
              ),
            ),
          );
          setState(() => _canLeave = true);
          await WidgetsBinding.instance.endOfFrame;
          if (mounted) Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String? required(String? value) =>
      value == null || value.trim().isEmpty ? 'Thông tin bắt buộc' : null;

  InputDecoration _inputDecoration({
    required String labelText,
    required IconData prefixIcon,
    String? hintText,
    Widget? suffixIcon,
    bool isReadOnly = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      helperText: needsCorrection(labelText) ? 'Admin yêu cầu bổ sung mục này' : null,
      helperStyle: const TextStyle(color: Color(0xFFDC2626)),
      labelStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: Icon(
        prefixIcon,
        color: isReadOnly ? const Color(0xFF94A3B8) : PartnerColors.primary,
        size: 20,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: needsCorrection(labelText) ? const Color(0xFFFEF2F2) : isReadOnly ? const Color(0xFFF1F5F9) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: needsCorrection(labelText) ? const Color(0xFFDC2626) : isReadOnly ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PartnerColors.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PartnerColors.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PartnerColors.error, width: 1.8),
      ),
    );
  }

  InputDecoration _dateBoxDecoration({required String labelText}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PartnerColors.primary, width: 1.8),
      ),
    );
  }

  Widget _birthDateDropdown({
    required String label,
    required int? value,
    required List<int> values,
    required String Function(int) format,
    required ValueChanged<int?> onChanged,
  }) {
    const textStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: PartnerColors.navy,
    );
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      itemHeight: 48,
      menuMaxHeight: 256,
      dropdownColor: PartnerColors.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      style: textStyle,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 18,
        color: PartnerColors.muted,
      ),
      decoration: _dateBoxDecoration(labelText: label),
      hint: const Text(
        'Chọn',
        style: TextStyle(fontSize: 13, color: PartnerColors.muted),
      ),
      selectedItemBuilder: (context) => values
          .map(
            (item) => Align(
              alignment: Alignment.centerLeft,
              child: Text(format(item), style: textStyle),
            ),
          )
          .toList(),
      items: values.map((item) {
        final selected = item == value;
        return DropdownMenuItem<int>(
          value: item,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? PartnerColors.softBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    format(item),
                    style: textStyle.copyWith(
                      color: selected
                          ? PartnerColors.primary
                          : PartnerColors.navy,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: PartnerColors.primary,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
      onChanged: canEdit('Ngày sinh') ? onChanged : null,
    );
  }

  Future<void> _loadIdentityImages() async {
    try {
      final result = await widget.session.request('/verifications/me');
      if (!mounted || result == null) return;
      setState(() {
        verification = Map<String, dynamic>.from(result);
        final sides = savedIdentitySides(verification);
        frontImageUploaded = sides.contains('FRONT');
        backImageUploaded = sides.contains('BACK');
        portraitImageUploaded = sides.contains('SELFIE');
        if (cccdNumber.text.isEmpty && result['documentNumber'] != null) {
          cccdNumber.text = result['documentNumber'].toString();
        }
      });
      for (final document in result['documents'] as List? ?? []) {
        if (document['scanStatus'] != 'CLEAN') continue;
        final side = document['side'] == 'SELFIE'
            ? 'PORTRAIT'
            : document['side'].toString();
        try {
          final response = await widget.session.request(
            '/verifications/${result['id']}/documents/${document['id']}/url',
          );
          if (!mounted) return;
          setState(() {
            imageUrls[side] = response['url'].toString();
            if (side == 'FRONT') frontImageUploaded = true;
            if (side == 'BACK') backImageUploaded = true;
            if (side == 'PORTRAIT') portraitImageUploaded = true;
          });
        } catch (_) {
          // Keep locally selected images available when a saved image cannot load.
        }
      }
    } catch (_) {
      // A new applicant may not have a verification record yet.
    }
  }

  Widget _identityImage(String side, {BoxFit fit = BoxFit.cover}) {
    Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
        const Center(
          child: Text('Không tải được ảnh', textAlign: TextAlign.center),
        );
    if (previews.containsKey(side)) {
      return Image.memory(previews[side]!, fit: fit, errorBuilder: fallback);
    }
    return Image.network(imageUrls[side]!, fit: fit, errorBuilder: fallback);
  }

  Future<void> _viewIdentityImage(String side, String title) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          height: MediaQuery.sizeOf(dialogContext).height * .75,
          child: Column(
            children: [
              ListTile(
                title: Text(title),
                trailing: IconButton(
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: _identityImage(side, fit: BoxFit.contain),
                  ),
                ),
              ),
              if (canEdit(sideLabel(side)))
                TextButton.icon(
                  icon: const Icon(Icons.upload),
                  label: const Text('Đổi ảnh'),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _pickImage(side);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _ensureIdentityDraft() async {
    await widget.session.request('/users/me/modes/tasker', method: 'POST');
    var result = await widget.session.request('/verifications/me');
    if (result == null || ['REJECTED', 'EXPIRED'].contains(result['status'])) {
      result = await widget.session.request('/verifications', method: 'POST');
    }
    verification = Map<String, dynamic>.from(result);
  }

  Future<void> _saveIdentityDraft({bool submit = false}) async {
    if (verification == null && cccdNumber.text.trim().isEmpty) return;
    if (cccdNumber.text.isNotEmpty &&
        !RegExp(r'^[0-9]{12}$').hasMatch(cccdNumber.text)) {
      throw StateError('CCCD phải gồm đúng 12 chữ số.');
    }
    await _ensureIdentityDraft();
    if (verification!['status'] == 'DRAFT' ||
        verification!['status'] == 'SUBMITTED') {
      verification = Map<String, dynamic>.from(
        await widget.session.request(
          '/verifications/${verification!['id']}/draft',
          method: 'PATCH',
          body: {
            'legalName': name.text.trim(),
            'documentType': 'NATIONAL_ID',
            'documentNumber': cccdNumber.text.trim(),
          },
        ),
      );
    }
    if (submit && verification!['status'] == 'DRAFT') {
      final documents = verification!['documents'] as List? ?? [];
      if (![
        'FRONT',
        'BACK',
        'SELFIE',
      ].every((side) => documents.any((d) => d['side'] == side))) {
        throw StateError(
          'Cần tải thành công cả hai mặt CCCD và ảnh chân dung.',
        );
      }
      verification = Map<String, dynamic>.from(
        await widget.session.request(
          '/verifications/${verification!['id']}/submit',
          method: 'POST',
          body: {'consent': true},
        ),
      );
    }
  }

  Future<void> _pickImage(String side) async {
    if (!canEdit(sideLabel(side))) return;
    if (uploadingIdentity || busy) return;
    setState(() {
      uploadingIdentity = true;
      error = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
      );
      if (file == null) return;
      final length = await file.length();
      if (length == null || length <= 0 || length > 10 * 1024 * 1024) {
        throw StateError('Ảnh tối đa 10 MB.');
      }
      final bytes = await file.readAsBytes();
      await _ensureIdentityDraft();
      final result = await widget.session.uploadVerificationImage(
        verification!['id'],
        side == 'PORTRAIT' ? 'SELFIE' : side,
        bytes,
      );
      if (!mounted) return;
      setState(() {
        verification = Map<String, dynamic>.from(result);
        previews[side] = bytes;
        if (side == 'FRONT') frontImageUploaded = true;
        if (side == 'BACK') backImageUploaded = true;
        if (side == 'PORTRAIT') portraitImageUploaded = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu ảnh vào hồ sơ trên hệ thống.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Chưa lưu được ảnh: $e');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error!)));
      }
    } finally {
      if (mounted) setState(() => uploadingIdentity = false);
    }
  }

  Widget _idPhotoBox({
    required String title,
    required String side,
    required bool isUploaded,
    required IconData icon,
  }) {
    return InkWell(
      onTap: () => previews.containsKey(side) || imageUrls.containsKey(side)
          ? _viewIdentityImage(side, title)
          : _pickImage(side),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 130,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: needsCorrection(sideLabel(side)) ? const Color(0xFFFEF2F2) : isUploaded ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: needsCorrection(sideLabel(side)) ? const Color(0xFFDC2626) : isUploaded
                ? const Color(0xFF86EFAC)
                : const Color(0xFFCBD5E1),
            width: isUploaded ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (previews.containsKey(side) || imageUrls.containsKey(side))
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: double.infinity,
                    child: _identityImage(side),
                  ),
                ),
              )
            else
              Icon(icon, size: 26, color: const Color(0xFF64748B)),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isUploaded
                    ? const Color(0xFF15803D)
                    : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              needsCorrection(sideLabel(side)) ? 'Cần bổ sung / thay ảnh' : isUploaded ? 'Đã tải lên ✓' : 'Bấm để tải',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: isUploaded
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentitySection() {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: PartnerColors.softBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.badge_outlined,
                        color: PartnerColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Định danh & CCCD',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: PartnerColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Tích hợp tải ảnh CCCD 2 mặt & ảnh chân dung trực tiếp trong hồ sơ.',
            style: TextStyle(
              fontSize: 12,
              color: PartnerColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            enabled: canEdit('Số CCCD / Mã định danh'),
            controller: cccdNumber,
            decoration: _inputDecoration(
              labelText: 'Số CCCD / Mã định danh (12 số)',
              prefixIcon: Icons.pin_outlined,
              hintText:
                  verification?['documentNumber'] ?? 'Ví dụ: 001095012345',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            validator: (value) =>
                value != null &&
                    value.isNotEmpty &&
                    !RegExp(r'^[0-9]{12}$').hasMatch(value)
                ? 'CCCD phải gồm đúng 12 chữ số.'
                : null,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _idPhotoBox(
                  title: 'Mặt trước CCCD',
                  side: 'FRONT',
                  isUploaded: frontImageUploaded,
                  icon: Icons.credit_card_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _idPhotoBox(
                  title: 'Mặt sau CCCD',
                  side: 'BACK',
                  isUploaded: backImageUploaded,
                  icon: Icons.flip_to_back_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _idPhotoBox(
                  title: 'Ảnh chân dung',
                  side: 'PORTRAIT',
                  isUploaded: portraitImageUploaded,
                  icon: Icons.face_rounded,
                ),
              ),
            ],
          ),
          if (uploadingIdentity) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: PartnerColors.muted),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: PartnerColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: PartnerColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: widget.readOnly || _canLeave,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) save(personalOnly: true);
    },
    child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: PartnerColors.navy,
          ),
          onPressed: busy || uploadingIdentity
              ? null
              : () => save(personalOnly: true),
        ),
        title: Text(
          requestedChanges.isNotEmpty ? 'Chặng 1: Bổ sung hồ sơ' : 'Hồ sơ ứng tuyển',
          style: const TextStyle(
            color: PartnerColors.navy,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: form,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modern Stepper progress indicator
                if (requestedChanges.isNotEmpty) Container(
                  margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFDC2626))),
                  child: Text('Hồ sơ thiếu — cần bổ sung:\n${requestedChanges.map((item) => '• $item').join('\n')}', style: const TextStyle(color: Color(0xFFDC2626))),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
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
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: PartnerColors.softBlue,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: PartnerColors.softBlueBorder,
                              ),
                            ),
                            child: Text(
                              'BƯỚC ${step + 1} / 3',
                              style: const TextStyle(
                                color: PartnerColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Text(
                            step == 0
                                ? 'Tiếp theo: Khu vực'
                                : step == 1
                                ? 'Tiếp theo: Xác nhận'
                                : 'Xác nhận đăng ký',
                            style: const TextStyle(
                              color: PartnerColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(3, (i) {
                          final isActive = i == step;
                          final isDone = i < step;
                          return Expanded(
                            child: Container(
                              height: 5,
                              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                              decoration: BoxDecoration(
                                color: isDone || isActive
                                    ? PartnerColors.primary
                                    : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                Text(
                  [
                    'Thông tin cá nhân',
                    'Khu vực tuyển dụng',
                    'Kiểm tra & xác nhận',
                  ][step],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: PartnerColors.navy,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    'Vui lòng điền đúng thông tin để hồ sơ được kích hoạt nhanh nhất.',
                    'Bắt buộc chọn ít nhất 1 khu vực (tỉnh thành, quận/huyện) bạn sẵn sàng làm việc.',
                    'Xem lại toàn bộ hồ sơ cẩn thận trước khi gửi đăng ký chính thức.',
                  ][step],
                  style: const TextStyle(
                    fontSize: 13,
                    color: PartnerColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Keep form fields mounted across steps so validation always covers personal information.
                Visibility(
                  visible: step == 0,
                  maintainState: true,
                  child: Column(
                    children: [
                      TextFormField(
                        enabled: canEdit('Họ và tên'),
                        controller: name,
                        decoration: _inputDecoration(
                          labelText: 'Họ và tên',
                          prefixIcon: Icons.person_outline_rounded,
                          hintText: 'Ví dụ: Nguyễn Văn An',
                        ),
                        validator: required,
                        maxLength: 160,
                        buildCounter: (
                          _, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) => null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        enabled: canEdit('Số điện thoại liên hệ'),
                        controller: phone,
                        decoration: _inputDecoration(
                          labelText: 'Điện thoại liên hệ',
                          prefixIcon: Icons.phone_outlined,
                          hintText: 'Ví dụ: 0912345678',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: required,
                      ),
                      const SizedBox(height: 16),
                      // 3 separate boxes: Ngày, Tháng, Năm (chỉ hiện trên 18 tuổi)
                      Builder(
                        builder: (context) {
                          final now = DateTime.now();
                          final maxAdultYear = now.year - 18;
                          final minYear = (dobYear != null && dobYear! < 1940)
                              ? dobYear!
                              : 1940;
                          final eligibleYears = List<int>.generate(
                            maxAdultYear - minYear + 1,
                            (i) => maxAdultYear - i,
                          );
                          final daysInMonth =
                              (dobYear != null && dobMonth != null)
                              ? DateTime(dobYear!, dobMonth! + 1, 0).day
                              : 31;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.cake_outlined,
                                      size: 18,
                                      color: PartnerColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Ngày sinh',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: PartnerColors.navy,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: PartnerColors.softBlue,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: PartnerColors.softBlueBorder,
                                        ),
                                      ),
                                      child: const Text(
                                        'Từ đủ 18 tuổi',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: PartnerColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      icon: const Icon(
                                        Icons.calendar_month_rounded,
                                        color: PartnerColors.primary,
                                        size: 20,
                                      ),
                                      tooltip: 'Chọn nhanh từ lịch',
                                      onPressed: !canEdit('Ngày sinh')
                                          ? null
                                          : () async {
                                              final maxAdultDate = DateTime(
                                                now.year - 18,
                                                now.month,
                                                now.day,
                                              );
                                              final initial =
                                                  (dobYear != null &&
                                                      dobMonth != null &&
                                                      dobDay != null)
                                                  ? DateTime(
                                                      dobYear!,
                                                      dobMonth!,
                                                      dobDay!,
                                                    )
                                                  : DateTime(
                                                      now.year - 20,
                                                      1,
                                                      1,
                                                    );
                                              final picked =
                                                  await showDatePicker(
                                                    context: context,
                                                    initialDate:
                                                        initial.isAfter(
                                                          maxAdultDate,
                                                        )
                                                        ? maxAdultDate
                                                        : initial,
                                                    firstDate: DateTime(1940),
                                                    lastDate: maxAdultDate,
                                                    helpText: 'CHỌN NGÀY SINH (TỪ ĐỦ 18 TUỔI)',
                                                  );
                                              if (picked != null) {
                                                setState(() {
                                                  dobYear = picked.year;
                                                  dobMonth = picked.month;
                                                  dobDay = picked.day;
                                                  _syncDob();
                                                  if (error != null) {
                                                    error = null;
                                                  }
                                                });
                                              }
                                            },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _birthDateDropdown(
                                        label: 'Ngày',
                                        value:
                                            (dobDay != null &&
                                                dobDay! <= daysInMonth)
                                            ? dobDay
                                            : null,
                                        values: List.generate(
                                          daysInMonth,
                                          (i) => i + 1,
                                        ),
                                        format: (value) =>
                                            value.toString().padLeft(2, '0'),
                                        onChanged: (value) {
                                          setState(() {
                                            dobDay = value;
                                            _syncDob();
                                            if (error != null) error = null;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _birthDateDropdown(
                                        label: 'Tháng',
                                        value: dobMonth,
                                        values: List.generate(12, (i) => i + 1),
                                        format: (value) =>
                                            value.toString().padLeft(2, '0'),
                                        onChanged: (value) {
                                          setState(() {
                                            dobMonth = value;
                                            _syncDob();
                                            if (error != null) error = null;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _birthDateDropdown(
                                        label: 'Năm',
                                        value:
                                            (dobYear != null &&
                                                dobYear! <= maxAdultYear)
                                            ? dobYear
                                            : null,
                                        values: eligibleYears,
                                        format: (value) => value.toString(),
                                        onChanged: (value) {
                                          setState(() {
                                            dobYear = value;
                                            _syncDob();
                                            if (error != null) error = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                FormField<String>(
                                  validator: (_) => _validateDob(),
                                  builder: (state) {
                                    if (state.hasError) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8,
                                          left: 4,
                                        ),
                                        child: Text(
                                          state.errorText!,
                                          style: const TextStyle(
                                            color: PartnerColors.error,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        enabled: !widget.readOnly,
                        initialValue: widget.application['email'],
                        readOnly: true,
                        decoration: _inputDecoration(
                          labelText: 'Email tài khoản',
                          prefixIcon: Icons.mail_outline_rounded,
                          isReadOnly: true,
                          suffixIcon: const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildIdentitySection(),
                    ],
                  ),
                ),
                if (step == 1) ...[
                  if (widget.application['firstSubmittedAt'] != null && !canEdit('Khu vực làm việc'))
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Hồ sơ đã nộp. Khu vực tuyển dụng đã được khóa.',
                      ),
                    ),
                  AbsorbPointer(
                    absorbing:
                        !canEdit('Khu vực làm việc') ||
                        (widget.application['firstSubmittedAt'] != null && requestedChanges.isEmpty),
                    child: _buildRecruitmentAreasSection(),
                  ),
                ],
                if (step == 2) ...[
                  Container(
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: PartnerColors.softBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.assignment_turned_in_outlined,
                                color: PartnerColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Tóm tắt hồ sơ ứng tuyển',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: PartnerColors.navy,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 26, color: Color(0xFFF1F5F9)),
                        _buildSummaryRow(
                          Icons.person_outline,
                          'Họ và tên',
                          name.text.isEmpty ? 'Chưa điền' : name.text,
                        ),
                        _buildSummaryRow(
                          Icons.phone_outlined,
                          'Điện thoại',
                          phone.text.isEmpty ? 'Chưa điền' : phone.text,
                        ),
                        _buildSummaryRow(
                          Icons.cake_outlined,
                          'Ngày sinh',
                          dob.text.isEmpty ? 'Chưa điền' : dob.text,
                        ),
                        _buildSummaryRow(
                          Icons.badge_outlined,
                          'Số CCCD / ĐDCN',
                          cccdNumber.text.isEmpty
                              ? 'Chưa điền'
                              : cccdNumber.text,
                        ),
                        _buildSummaryRow(
                          Icons.photo_library_outlined,
                          'Ảnh CCCD & Chân dung',
                          (frontImageUploaded &&
                                  backImageUploaded &&
                                  portraitImageUploaded)
                              ? 'Đã tải đủ 3 ảnh ✓'
                              : '${[frontImageUploaded, backImageUploaded, portraitImageUploaded].where((x) => x).length}/3 ảnh đã lưu trên hệ thống',
                        ),
                        _buildSummaryRow(
                          Icons.location_on_outlined,
                          'Khu vực',
                          '${areaIds.length} khu vực đã chọn',
                        ),
                        if (areaIds.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Địa bàn làm việc:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => setState(() => step = 1),
                                      borderRadius: BorderRadius.circular(6),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          'Chỉnh sửa',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: PartnerColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: areaIds.map((id) {
                                    final matched = allAvailableAreas
                                        .firstWhere(
                                          (a) => a['id'] == id,
                                          orElse: () => {
                                            'city': '',
                                            'name': id,
                                          },
                                        );
                                    final label =
                                        matched['city'].toString().isNotEmpty
                                        ? '${matched['city']} • ${matched['name']}'
                                        : matched['name'].toString();
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: PartnerColors.navy,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: PartnerColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Số điện thoại này là thông tin liên hệ chính thức để điều phối công việc. Vui lòng bảo đảm thông tin chính xác của bạn.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF1E3A8A),
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            error!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PartnerPillButton(
                  label: widget.readOnly
                      ? (step < 2 ? 'Tiếp tục xem' : 'Đóng')
                      : busy
                      ? 'Đang lưu…'
                      : step < 2
                      ? 'Tiếp tục'
                      : [
                          'PROFILE_INCOMPLETE',
                          'PRELIMINARY_REVIEW',
                        ].contains(widget.application['status'])
                      ? 'Lưu bổ sung hồ sơ'
                      : 'Gửi đăng ký',
                  isLoading: busy,
                  icon: step < 2
                      ? Icons.arrow_forward_rounded
                      : Icons.check_circle_outline_rounded,
                  onPressed: busy
                      ? null
                      : () =>
                            step < 2 ? save(advance: true) : save(submit: true),
                ),
                if (step > 0) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton.icon(
                      onPressed: busy ? null : () => setState(() => step--),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        size: 16,
                        color: PartnerColors.muted,
                      ),
                      label: const Text(
                        'Quay lại',
                        style: TextStyle(
                          color: PartnerColors.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildRecruitmentAreasSection() {
    final availableCityNames =
        allAvailableAreas
            .where(
              (area) =>
                  selectedRegion == 'Tất cả' ||
                  area['region'] == selectedRegion,
            )
            .map((area) => area['city'].toString())
            .toSet()
            .toList()
          ..sort();

    if (selectedCity == null || !availableCityNames.contains(selectedCity)) {
      selectedCity = null;
      if (availableCityNames.contains('TP. Hồ Chí Minh')) {
        selectedCity = 'TP. Hồ Chí Minh';
      } else if (availableCityNames.contains('Hà Nội')) {
        selectedCity = 'Hà Nội';
      } else if (availableCityNames.isNotEmpty) {
        selectedCity = availableCityNames.first;
      }
    }

    // 2. Lọc danh sách địa bàn / quận huyện
    final query = areaSearchQuery.trim().toLowerCase();
    final displayedAreas = allAvailableAreas.where((area) {
      final cityName = (area['city'] ?? '').toString();
      final distName = (area['name'] ?? '').toString();
      final regionName = (area['region'] ?? '').toString();

      if (query.isNotEmpty) {
        return distName.toLowerCase().contains(query) ||
            cityName.toLowerCase().contains(query);
      }

      if (selectedRegion != 'Tất cả' && regionName != selectedRegion) {
        return false;
      }

      if (selectedCity != null && selectedCity!.isNotEmpty) {
        return cityName == selectedCity;
      }

      return true;
    }).toList();

    final displayedIds = displayedAreas.map((a) => a['id'].toString()).toSet();
    final allCurrentSelected =
        displayedAreas.isNotEmpty &&
        displayedAreas.every((a) => areaIds.contains(a['id']));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filters use only cities with published recruiting areas.
        Container(
          padding: const EdgeInsets.all(18),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PartnerColors.softBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.map_outlined,
                      color: PartnerColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Địa bàn tuyển dụng',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: PartnerColors.navy,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${VietnamLocations.provinces.length} tỉnh',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Ô TÌM KIẾM QUẬN / HUYỆN / TỈNH THÀNH
              TextField(
                controller: searchCtrl,
                onChanged: (val) {
                  setState(() {
                    areaSearchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên quận, huyện hoặc tỉnh thành...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: PartnerColors.primary,
                    size: 20,
                  ),
                  suffixIcon: areaSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            searchCtrl.clear();
                            setState(() {
                              areaSearchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFD),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: PartnerColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // BỘ LỌC THEO MIỀN
              const Text(
                'Khu vực địa lý:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Tất cả', 'Miền Bắc', 'Miền Trung', 'Miền Nam']
                      .map((region) {
                        final isSel = selectedRegion == region;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(region),
                            selected: isSel,
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  selectedRegion = region;
                                });
                              }
                            },
                            selectedColor: PartnerColors.primary,
                            backgroundColor: const Color(0xFFF1F5F9),
                            labelStyle: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSel
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                            side: BorderSide(
                              color: isSel
                                  ? PartnerColors.primary
                                  : const Color(0xFFE2E8F0),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Cities available for recruitment.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Tỉnh / Thành phố:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${availableCityNames.length} tỉnh',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: availableCityNames.contains(selectedCity)
                        ? selectedCity
                        : (availableCityNames.isNotEmpty
                              ? availableCityNames.first
                              : null),
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: PartnerColors.navy,
                    ),
                    selectedItemBuilder: (context) =>
                        availableCityNames.map((city) {
                          return Row(
                            children: [
                              const Icon(
                                Icons.location_city_rounded,
                                size: 18,
                                color: PartnerColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  city,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: PartnerColors.navy,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                    items: availableCityNames.map((city) {
                      return DropdownMenuItem<String>(
                        value: city,
                        child: Text(
                          city,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: PartnerColors.navy,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (newCity) {
                      if (newCity != null) {
                        setState(() {
                          selectedCity = newCity;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. DANH SÁCH QUẬN / HUYỆN & NÚT CHỌN NHANH / XÓA NHANH
        Container(
          padding: const EdgeInsets.all(18),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          query.isNotEmpty
                              ? 'Kết quả tìm kiếm'
                              : '$selectedCity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: PartnerColors.navy,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${displayedAreas.length} quận / huyện',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (displayedAreas.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        backgroundColor: allCurrentSelected
                            ? const Color(0xFFFEE2E2)
                            : PartnerColors.softBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          if (allCurrentSelected) {
                            areaIds.removeWhere(
                              (id) => displayedIds.contains(id),
                            );
                          } else {
                            for (final a in displayedAreas) {
                              final id = a['id'].toString();
                              if (!areaIds.contains(id)) {
                                areaIds.add(id);
                              }
                            }
                          }
                          if (error != null) error = null;
                        });
                      },
                      icon: Icon(
                        allCurrentSelected
                            ? Icons.clear_all_rounded
                            : Icons.done_all_rounded,
                        size: 16,
                        color: allCurrentSelected
                            ? const Color(0xFFDC2626)
                            : PartnerColors.primary,
                      ),
                      label: Text(
                        allCurrentSelected ? 'Bỏ chọn' : 'Chọn hết',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: allCurrentSelected
                              ? const Color(0xFFDC2626)
                              : PartnerColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              if (displayedAreas.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(
                        Icons.location_off_outlined,
                        size: 40,
                        color: Color(0xFFCBD5E1),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        query.isNotEmpty
                            ? 'Không tìm thấy khu vực nào khớp với "$query"'
                            : 'Chưa có khu vực đang mở tuyển',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        allAvailableAreas.isEmpty
                            ? 'Vui lòng quay lại khi có khu vực tuyển dụng mới.'
                            : 'Thử tìm từ khóa khác hoặc chọn tỉnh thành khác.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else ...[
                Column(
                  children:
                      (showAllAreas ? displayedAreas : displayedAreas.take(5))
                          .map((area) {
                            final id = area['id'].toString();
                            final name = area['name'].toString();
                            final city = area['city'].toString();
                            final isSelected = areaIds.contains(id);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: isSelected
                                    ? const Color(0xFFF0FDF4)
                                    : const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        areaIds.remove(id);
                                      } else {
                                        areaIds.add(id);
                                      }
                                      if (error != null) error = null;
                                    });
                                  },
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minHeight: 50,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF22C55E)
                                            : const Color(0xFFE2E8F0),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF16A34A)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFF16A34A)
                                                  : const Color(0xFFCBD5E1),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  size: 16,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  height: 1.25,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                                  color: isSelected
                                                      ? const Color(0xFF14532D)
                                                      : PartnerColors.navy,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (query.isNotEmpty ||
                                                  selectedCity != city) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  city,
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    height: 1.2,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Text(
                                            'Mở tuyển',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF15803D),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                ),
                if (displayedAreas.length > 5) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () =>
                          setState(() => showAllAreas = !showAllAreas),
                      icon: Icon(
                        showAllAreas
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: PartnerColors.primary,
                      ),
                      label: Text(
                        showAllAreas
                            ? 'Thu gọn danh sách (hiện 5 mục)'
                            : 'Xem thêm ${displayedAreas.length - 5} quận / huyện khác',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: PartnerColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
