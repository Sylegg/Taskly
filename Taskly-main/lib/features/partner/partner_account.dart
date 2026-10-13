import 'dart:async';
import 'package:flutter/material.dart';

import '../../auth/api.dart';
import 'partner_ui_kit.dart';
import 'partner_portrait.dart';

import 'recruitment_agreements.dart';
import 'partner_uniform_shop.dart';
import 'recruitment_office_visit.dart';
import 'recruitment_final_documents.dart';
import 'partner_help_center.dart';
import 'partner_work_areas.dart';
import 'partner_bank.dart';
import 'partner_notifications.dart';

class PartnerAccount extends StatefulWidget {
  const PartnerAccount({super.key, required this.session, this.onLogout});
  final Session session;
  final VoidCallback? onLogout;

  @override
  State<PartnerAccount> createState() => _PartnerAccountState();
}

class _PartnerAccountState extends State<PartnerAccount> {
  final form = GlobalKey<FormState>(),
      name = TextEditingController(),
      phone = TextEditingController();
  Map<String, dynamic>? profile;
  String language = 'vi';
  String? error, notice;
  bool busy = false;

  StreamSubscription<void>? _liveSubscription;
  @override
  void initState() {
    super.initState();
    _liveSubscription = widget.session.liveChanges.listen((_) { if (mounted) load(background: true); });
    load();
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  bool _refreshing = false;
  Future<void> load({bool background = false}) async {
    if (_refreshing || (background && busy)) return;
    _refreshing = true;
    if (!background) setState(() => busy = true);
    try {
      final result = await widget.session.request('/users/me');
      if (mounted) {
        setState(() {
          final old = profile;
          profile = Map<String, dynamic>.from(result);
          if (!background || name.text == (old?['fullName'] ?? '')) name.text = profile!['fullName'] ?? '';
          if (!background || phone.text == (old?['phone'] ?? '')) phone.text = profile!['phone'] ?? '';
          if (!background || language == (old?['language'] ?? 'vi')) language = profile!['language'] ?? 'vi';
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      _refreshing = false;
      if (mounted && !background) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final result = await widget.session.request(
        '/users/me/profile',
        method: 'PATCH',
        body: {
          'fullName': name.text.trim(),
          'phone': phone.text.trim(),
          'language': language,
        },
      );
      if (mounted) {
        setState(() {
          profile = Map<String, dynamic>.from(result);
          notice = 'Đã lưu thông tin tài khoản.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editAccount() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (editorContext) => StatefulBuilder(
          builder: (editorContext, refresh) => Scaffold(
            appBar: AppBar(title: const Text('Chỉnh sửa thông tin tài khoản')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: form,
                child: Column(
                  children: [
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    if (notice != null)
                      Text(
                        notice!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE8EDF5)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06214777),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: name,
                            enabled: !busy,
                            maxLength: 160,
                            decoration: InputDecoration(
                              labelText: 'Họ tên theo CCCD',
                              helperText: 'Tên theo hồ sơ CCCD, không thể tự chỉnh sửa.',
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) => v == null || v.trim().length < 2
                                ? 'Nhập họ tên hợp lệ'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: phone,
                            enabled: !busy,
                            maxLength: 10,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Điện thoại',
                              prefixIcon: const Icon(
                                Icons.phone_outlined,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) =>
                                v != null &&
                                    v.isNotEmpty &&
                                    !RegExp(r'^0[0-9]{9}$').hasMatch(v)
                                ? 'Số điện thoại gồm 10 chữ số, bắt đầu bằng 0'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          const SizedBox(height: 18),
                          Partner3DButton(
                            label: 'Lưu thông tin tài khoản',
                            icon: Icons.save_rounded,
                            onPressed: busy
                                ? null
                                : () async {
                                    final pending = save();
                                    refresh(() {});
                                    await pending;
                                    if (editorContext.mounted) refresh(() {});
                                  },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> changePassword() async {
    final current = TextEditingController(), next = TextEditingController();
    final key = GlobalKey<FormState>();
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        scrollable: true,
        title: const Text(
          'Đổi mật khẩu',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: PartnerColors.navy,
          ),
        ),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nhập mật khẩu hiện tại' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: next,
                obscureText: true,
                maxLength: 128,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    v == null || v.length < 10 ? 'Tối thiểu 10 ký tự' : null,
              ),
              const Text(
                'Sau khi đổi thành công, bạn sẽ cần đăng nhập lại.',
                style: TextStyle(fontSize: 12, color: PartnerColors.muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PartnerColors.primary,
            ),
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(c, true);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      setState(() => busy = true);
      try {
        await widget.session.request(
          '/users/me/change-password',
          method: 'POST',
          body: {'currentPassword': current.text, 'newPassword': next.text},
        );
        if (widget.onLogout != null) {
          widget.onLogout!();
        } else {
          await widget.session.logout();
        }
      } catch (e) {
        if (mounted) setState(() => error = e.toString());
      } finally {
        if (mounted) setState(() => busy = false);
      }
    }
    current.dispose();
    next.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        (name.text.trim().isNotEmpty
                ? name.text.trim()
                : profile?['fullName'] ?? 'Tasker Partner')
            .toString();
    final email = (profile?['email'] ?? '').toString();
    final initials = displayName.length >= 2
        ? displayName.substring(0, 2).toUpperCase()
        : 'TL';

    return Form(
      key: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. USER PROFILE CARD (HTML prototype style)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8EDF5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A214777),
                  blurRadius: 20,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                // 60x60 Avatar
                PartnerPortrait(
                  session: widget.session,
                  size: 58,
                  fallback: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE2EFFF), Color(0xFFBDCFFA)],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x181E5BF8),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2B61C2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: PartnerColors.navy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email.isNotEmpty ? email : 'Tài khoản TaskLy Partner',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: PartnerColors.muted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      const PartnerPillBadge(
                        text: 'Đối tác TaskLy',
                        type: 'blue',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Chỉnh sửa thông tin tài khoản',
                  onPressed: busy ? null : editAccount,
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: PartnerColors.navy,
                  ),
                ),
              ],
            ),
          ),

          if (busy) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],

          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD5DB)),
              ),
              child: Text(
                error!,
                style: const TextStyle(color: Color(0xFFCE4C55), fontSize: 12),
              ),
            ),
          ],

          if (notice != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE5FAF1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC9EEE0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF0B926B),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notice!,
                      style: const TextStyle(
                        color: Color(0xFF0B926B),
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 2. HỒ SƠ & HOẠT ĐỘNG
          const PartnerSectionTitle('Hồ sơ & hoạt động'),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PartnerItemTile(
              emoji: '🔔',
              title: 'Thông báo Đối tác',
              subtitle: 'Lịch sử nhận việc, tin nhắn khách & thưởng ngày',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PartnerNotificationPage(session: widget.session),
                ),
              ),
            ),
          ),
          PartnerItemTile(
            emoji: '🏦',
            title: 'Tài khoản ngân hàng',
            subtitle: 'Ngân hàng nhận thu nhập (duy nhất 1 tài khoản)',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PartnerBank(session: widget.session),
            )),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PartnerItemTile(
              emoji: '📍',
              title: 'Khu vực làm việc',
              subtitle: 'Chọn tỉnh/thành phố nhận việc',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PartnerWorkAreas(session: widget.session),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PartnerItemTile(
              emoji: '🛡️',
              title: 'Cam kết & bảo vệ dữ liệu',
              subtitle: 'Thỏa thuận hợp tác và chính sách',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      RecruitmentAgreements(session: widget.session),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PartnerItemTile(
              emoji: '🏢',
              title: 'Văn phòng TaskLy Hub',
              subtitle: 'Xác minh trực tiếp & nhận đồng phục',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      RecruitmentOfficeVisit(session: widget.session),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PartnerItemTile(
              emoji: '📑',
              title: 'Hợp đồng & Hồ sơ đối tác',
              subtitle: 'Điều khoản hợp tác và hồ sơ kích hoạt',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      RecruitmentFinalDocuments(session: widget.session),
                ),
              ),
            ),
          ),

          // 3. ĐỒNG PHỤC & TRANG THIẾT BỊ (Mục riêng biệt)
          const PartnerSectionTitle('Đồng phục & Trang thiết bị'),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF0FDF4), Color(0xFFF8FAFC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF86EFAC).withValues(alpha: 0.7),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A059669),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PartnerUniformShop(session: widget.session),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '👕',
                            style: TextStyle(fontSize: 26),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Cửa hàng Đồng phục & Trang bị',
                                      style: TextStyle(
                                        fontSize: 14.5,
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
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Mua sắm',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Mua combo gói đồng phục hoặc mua lẻ áo, nón, tạp dề, túi đồ nghề chính hãng',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: PartnerColors.muted,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. TRUNG TÂM HỖ TRỢ & TRỢ GIÚP
          const PartnerSectionTitle('Trung tâm hỗ trợ & Trợ giúp'),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PartnerItemTile(
              emoji: '🎧',
              title: 'Trung tâm hỗ trợ Đối tác (Help Center)',
              subtitle: 'Hotline 24/7, gửi ticket, xử lý sự cố & FAQ',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PartnerHelpCenter(session: widget.session, initialTab: 0),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PartnerItemTile(
              emoji: '🚨',
              title: 'Báo cáo sự cố khi làm việc',
              subtitle:
                  'Khách vắng mặt, hủy việc đột xuất, sai địa chỉ & an toàn',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PartnerHelpCenter(session: widget.session, initialTab: 1),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PartnerItemTile(
              emoji: '📝',
              title: 'Gửi phiếu yêu cầu hỗ trợ (Ticket)',
              subtitle: 'Khiếu nại thu nhập, đối soát ví & tài khoản',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PartnerHelpCenter(session: widget.session, initialTab: 2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PartnerItemTile(
              emoji: '📖',
              title: 'Quy chuẩn dịch vụ & Cẩm nang 5 sao',
              subtitle:
                  'Quy trình chuẩn nhận việc, ứng xử và bảo hiểm 50 triệu',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PartnerHelpCenter(session: widget.session, initialTab: 3),
                ),
              ),
            ),
          ),

          // Security & logout actions
          Partner3DButton(
            label: 'Đổi mật khẩu',
            variant: Partner3DVariant.outline,
            icon: Icons.lock_outline_rounded,
            onPressed: busy ? null : changePassword,
          ),
          const SizedBox(height: 10),
          Partner3DButton(
            label: 'Đăng xuất',
            variant: Partner3DVariant.red,
            icon: Icons.logout_rounded,
            onPressed: busy ? null : widget.onLogout,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
