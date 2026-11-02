import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'entry.dart';

enum AuthStep { login, register, verify, forgot, reset, verified, resetDone }

class AuthPage extends StatefulWidget {
  final Session session;
  final AuthStep initialStep;
  const AuthPage({
    super.key,
    required this.session,
    this.initialStep = AuthStep.login,
  });
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      phone = TextEditingController(),
      code = TextEditingController();
  AuthStep step = AuthStep.login;
  bool busy = false, terms = false, showPassword = false;
  bool requireVerificationEmail = false;
  String? error, notice;
  DateTime? sentAt;
  int cooldown = 0, validity = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    step = widget.initialStep;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (sentAt != null && mounted) {
        setState(() {
          final elapsed = DateTime.now().difference(sentAt!).inSeconds;
          cooldown = (60 - elapsed).clamp(0, 60);
          if (validity > 0) validity = (300 - elapsed).clamp(0, 300);
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final c in [email, password, name, phone, code]) {
      c.dispose();
    }
    super.dispose();
  }

  void go(AuthStep next) {
    FocusScope.of(context).unfocus();
    setState(() {
      step = next;
      error = null;
      notice = null;
      code.clear();
    });
  }

  String get address => email.text.trim().toLowerCase();
  String normalizePhone(String value) {
    final number = value.replaceAll(RegExp(r'[\s-]'), '');
    return number.startsWith('+84') ? '0${number.substring(3)}' : number;
  }

  String? phoneValidator(String? value) =>
      RegExp(r'^0[0-9]{9}$').hasMatch(normalizePhone(value ?? ''))
      ? null
      : 'Vui lòng nhập số điện thoại Việt Nam hợp lệ.';
  String get masked {
    final pieces = address.split('@');
    return pieces.length == 2
        ? '${pieces[0].substring(0, pieces[0].length.clamp(0, 2))}***@${pieces[1]}'
        : address;
  }

  void sent() {
    sentAt = DateTime.now();
    cooldown = 60;
    validity = 300;
  }

  String? emailValidator(String? v) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v?.trim() ?? '')
      ? null
      : 'Vui lòng nhập email hợp lệ.';
  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    if (step == AuthStep.register && !terms) {
      setState(() => error = 'Bạn cần đồng ý với Điều khoản để tiếp tục.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    FocusScope.of(context).unfocus();
    final submittedStep = step;
    try {
      switch (submittedStep) {
        case AuthStep.login:
          await widget.session.login(
            normalizePhone(phone.text),
            password.text,
            rememberMe: true,
            byPhone: true,
          );
          break;
        case AuthStep.register:
          var number = phone.text.replaceAll(RegExp(r'[\s-]'), '');
          if (number.startsWith('+84')) number = '0${number.substring(3)}';
          setState(() {
            step = AuthStep.verify;
            code.clear();
            sentAt = null;
            cooldown = 0;
            validity = 0;
            notice = 'Đang gửi mã xác minh tới Gmail của bạn…';
          });
          await widget.session.api.call(
            '/auth/register',
            method: 'POST',
            body: {
              'email': address,
              'appType': Session.appType,
              'fullName': name.text.trim(),
              'phone': number,
              'password': password.text,
            },
          );
          if (!mounted) return;
          setState(() {
            step = AuthStep.verify;
            code.clear();
            notice = 'Mã đã được gửi. Kiểm tra hộp thư đến và mục Spam.';
            sent();
          });
          break;
        case AuthStep.verify:
          await widget.session.api.call(
            '/auth/verify-otp',
            method: 'POST',
            body: {'email': address, 'code': code.text},
          );
          if (!mounted) return;
          setState(() => step = AuthStep.verified);
          break;
        case AuthStep.forgot:
          await widget.session.api.call(
            '/auth/forgot-password',
            method: 'POST',
            body: {'email': address},
          );
          if (!mounted) return;
          setState(() {
            step = AuthStep.reset;
            sent();
            notice =
                'Nếu email tồn tại trong hệ thống, mã xác minh đã được gửi.';
          });
          break;
        case AuthStep.reset:
          await widget.session.api.call(
            '/auth/reset-password',
            method: 'POST',
            body: {
              'email': address,
              'code': code.text,
              'newPassword': password.text,
            },
          );
          if (!mounted) return;
          password.clear();
          setState(() => step = AuthStep.resetDone);
          break;
        default:
          break;
      }
    } on ApiFailure catch (e) {
      if (!mounted) return;
      setState(() {
        if (submittedStep == AuthStep.register &&
            (e.code == 'TIMEOUT' || e.code == 'OTP_RATE_LIMITED')) {
          step = AuthStep.verify;
          code.clear();
          sentAt = null;
          cooldown = e.code == 'OTP_RATE_LIMITED' ? 60 : 0;
          validity = 0;
          if (cooldown > 0) sentAt = DateTime.now();
          notice = e.code == 'TIMEOUT'
              ? 'Phản hồi đăng ký chậm. Nếu Gmail đã nhận mã, nhập mã bên dưới. Nếu chưa nhận, hãy gửi lại mã hoặc quay lại đăng ký.'
              : 'Mã đã được yêu cầu gần đây. Nhập mã trong Gmail hoặc chờ để gửi lại.';
        } else if (e.code == 'EMAIL_VERIFICATION_REQUIRED') {
          requireVerificationEmail = submittedStep == AuthStep.login;
          step = AuthStep.verify;
          notice = 'Email chưa được xác minh. Nhập mã đã nhận hoặc gửi lại mã.';
        } else {
          if (submittedStep == AuthStep.register) step = AuthStep.register;
          error = e.message;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          if (submittedStep == AuthStep.register) step = AuthStep.register;
          error = 'Không thể hoàn tất yêu cầu. Vui lòng thử lại.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resend() async {
    if (cooldown > 0 || busy) return;
    if (emailValidator(email.text) != null) {
      setState(() => error = 'Vui lòng nhập email đã đăng ký để nhận mã.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.api.call(
        step == AuthStep.reset ? '/auth/forgot-password' : '/auth/resend-otp',
        method: 'POST',
        body: {'email': address},
      );
      if (mounted) {
        setState(() {
          sent();
          notice = 'Mã mới đã được gửi. Vui lòng kiểm tra email.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool secret = false,
    double bottomSpacing = 14,
    TextInputType? keyboard,
    String? Function(String?)? validate,
  }) {
    final visible = showPassword;
    return Padding(
      padding: EdgeInsets.only(
        bottom: step == AuthStep.register ? 10 : bottomSpacing,
      ),
      child: TextFormField(
        controller: controller,
        enabled: !busy,
        obscureText: secret && !visible,
        keyboardType: keyboard,
        autocorrect: !secret,
        enableSuggestions: !secret,
        maxLength: secret ? 128 : null,
        autovalidateMode: AutovalidateMode.onUnfocus,
        validator: validate,
        onChanged: secret ? (_) => setState(() {}) : null,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: step == AuthStep.register
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
              : null,
          counterText: '',
          prefixIcon: Icon(icon, size: 21),
          suffixIcon: secret
              ? IconButton(
                  tooltip: visible ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                  onPressed: () => setState(() {
                    showPassword = !showPassword;
                  }),
                  icon: Icon(
                    visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  String? passwordValidator(String? v) =>
      (v ?? '').length < 10 ? 'Mật khẩu cần ít nhất 10 ký tự.' : null;
  Widget passwordFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      field(
        step == AuthStep.reset ? 'Mật khẩu mới' : 'Mật khẩu',
        password,
        Icons.lock_outline,
        secret: true,
        validate: passwordValidator,
      ),
      if (password.text.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            '${password.text.length >= 10 ? '✓' : '○'} Ít nhất 10 ký tự',
            style: const TextStyle(color: brand),
          ),
        ),
    ],
  );
  String clock(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';

  Widget verificationPage() => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                    child: Form(
                      key: form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: brand,
                                size: 30,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    partnerApp ? 'TaskLy Partner' : 'TaskLy',
                                    style: const TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w800,
                                      color: brandDark,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 36),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: brandSoft,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Icon(
                                Icons.mark_email_read_outlined,
                                size: 56,
                                color: brand,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Xác minh email',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Nhập mã gồm 6 chữ số được gửi tới',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF667085),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            masked,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: brandDark,
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (requireVerificationEmail)
                            field(
                              'Email đã đăng ký',
                              email,
                              Icons.mail_outline,
                              keyboard: TextInputType.emailAddress,
                              validate: emailValidator,
                            ),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFE2EEE6),
                              ),
                            ),
                            child: Column(
                              children: [
                                OtpField(
                                  controller: code,
                                  enabled: !busy,
                                  onChanged: () => setState(() {}),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.schedule,
                                      size: 16,
                                      color: Color(0xFF667085),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        validity > 0
                                            ? 'Mã có hiệu lực trong ${clock(validity)}'
                                            : 'Dùng mã mới nhất trong email',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF667085),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: cooldown > 0 || busy
                                      ? null
                                      : resend,
                                  child: Text(
                                    cooldown > 0
                                        ? 'Gửi lại mã sau ${clock(cooldown)}'
                                        : 'Chưa nhận được mã? Gửi lại',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (notice != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Text(
                                notice!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: brandDark,
                                ),
                              ),
                            ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFE5484D),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          const Spacer(),
                          FilledButton(
                            onPressed: busy || code.text.length != 6
                                ? null
                                : submit,
                            child: busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Xác minh'),
                                      SizedBox(width: 10),
                                      Icon(Icons.arrow_forward, size: 19),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: busy ? null : () => go(AuthStep.login),
                            child: const Text('Quay lại đăng nhập'),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'VIỆC NHỎ TRONG TẦM TAY',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2,
                              color: Color(0xFF8BA49A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (step == AuthStep.verify) return verificationPage();
    final artwork = step == AuthStep.login || step == AuthStep.register;
    final success = step == AuthStep.verified || step == AuthStep.resetDone;
    final titles = {
      AuthStep.login: 'Chào mừng bạn trở lại 👋',
      AuthStep.register: 'Tạo tài khoản TaskLy',
      AuthStep.verify: 'Xác minh email',
      AuthStep.forgot: 'Quên mật khẩu?',
      AuthStep.reset: 'Tạo mật khẩu mới',
      AuthStep.verified: 'Xác minh thành công!',
      AuthStep.resetDone: 'Đổi mật khẩu thành công',
    };
    final subtitles = {
      AuthStep.login: 'Đăng nhập để đặt dịch vụ, theo dõi công việc\nvà quản lý mọi thứ dễ dàng hơn.',
      AuthStep.register:
          'Tham gia TaskLy và đặt dịch vụ đáng tin cậy chỉ trong vài phút.',
      AuthStep.verify: 'Chúng tôi đã gửi mã gồm 6 chữ số tới:\n$masked',
      AuthStep.forgot: 'Nhập email đã đăng ký. Chúng tôi sẽ gửi mã xác minh giúp bạn đặt lại mật khẩu.',
      AuthStep.reset: 'Nhập mã được gửi tới $masked và chọn mật khẩu mới.',
      AuthStep.verified:
          'Tài khoản TaskLy của bạn đã sẵn sàng. Đăng nhập để bắt đầu.',
      AuthStep.resetDone: 'Bạn có thể đăng nhập bằng mật khẩu mới.',
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        if (artwork)
          Image.asset(
            step == AuthStep.register
                ? 'assets/images/nendangky.png'
                : 'assets/images/nendangnhap.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        Scaffold(
          backgroundColor: artwork ? Colors.transparent : null,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final content = Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!artwork)
                          SizedBox(
                            height: 150,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: brand,
                                          size: 32,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              partnerApp
                                                  ? 'TaskLy Partner'
                                                  : 'TaskLy',
                                              style: const TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w800,
                                                color: brandDark,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (!artwork)
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Icon(
                                      success
                                          ? Icons.check_circle_outline
                                          : step == AuthStep.verify
                                          ? Icons.mark_email_read_outlined
                                          : Icons.lock_reset,
                                      size: 64,
                                      color: brand,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              key: ValueKey(step),
                              padding: EdgeInsets.all(
                                step == AuthStep.register ? 18 : 22,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x12174D3D),
                                    blurRadius: 24,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: form,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      titles[step]!,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      subtitles[step]!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.6,
                                        color: Color(0xFF667085),
                                      ),
                                    ),
                                    SizedBox(
                                      height: step == AuthStep.register
                                          ? 16
                                          : 22,
                                    ),
                                    if (notice != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 14,
                                        ),
                                        child: Text(
                                          notice!,
                                          style: const TextStyle(
                                            color: brandDark,
                                          ),
                                        ),
                                      ),
                                    if (!success &&
                                        step != AuthStep.verify &&
                                        step != AuthStep.reset) ...[
                                      if (step == AuthStep.register)
                                        field(
                                          'Họ và tên',
                                          name,
                                          Icons.person_outline,
                                          validate: (v) =>
                                              (v?.trim().length ?? 0) >= 2
                                              ? null
                                              : 'Vui lòng nhập họ tên.',
                                        ),
                                      field(
                                        step == AuthStep.login
                                            ? 'Số điện thoại'
                                            : 'Email',
                                        step == AuthStep.login ? phone : email,
                                        step == AuthStep.login
                                            ? Icons.phone_outlined
                                            : Icons.mail_outline,
                                        keyboard: step == AuthStep.login
                                            ? TextInputType.phone
                                            : TextInputType.emailAddress,
                                        validate: step == AuthStep.login
                                            ? phoneValidator
                                            : emailValidator,
                                      ),
                                    ],
                                    if (step == AuthStep.login) ...[
                                      field(
                                        'Mật khẩu',
                                        password,
                                        Icons.lock_outline,
                                        secret: true,
                                        bottomSpacing: 0,
                                        validate: (v) => (v ?? '').isEmpty
                                            ? 'Vui lòng nhập mật khẩu.'
                                            : null,
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            minimumSize: const Size(0, 40),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          onPressed: busy
                                              ? null
                                              : () => go(AuthStep.forgot),
                                          child: const Text('Quên mật khẩu?'),
                                        ),
                                      ),
                                    ],
                                    if (step == AuthStep.register) ...[
                                      field(
                                        'Số điện thoại Việt Nam',
                                        phone,
                                        Icons.phone_outlined,
                                        keyboard: TextInputType.phone,
                                        validate: (v) =>
                                            RegExp(r'^(0\d{9}|\+84\d{9})$')
                                                .hasMatch(
                                                  (v ?? '').replaceAll(
                                                    RegExp(r'[\s-]'),
                                                    '',
                                                  ),
                                                )
                                            ? null
                                            : 'Số điện thoại không hợp lệ.',
                                      ),
                                      passwordFields(),
                                      Material(
                                        color: Colors.transparent,
                                        child: CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          value: terms,
                                          onChanged: busy
                                              ? null
                                              : (v) =>
                                                    setState(() => terms = v!),
                                          title: const Text(
                                            'Tôi đồng ý Điều khoản sử dụng và Chính sách quyền riêng tư.',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (step == AuthStep.verify ||
                                        step == AuthStep.reset) ...[
                                      OtpField(
                                        controller: code,
                                        enabled: !busy,
                                        onChanged: () => setState(() {}),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        validity > 0
                                            ? 'Mã có hiệu lực trong ${clock(validity)}'
                                            : 'Nhập mã mới nhất trong email. Nếu mã hết hạn, hãy gửi lại mã.',
                                        style: const TextStyle(
                                          color: Color(0xFF667085),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: cooldown > 0 || busy
                                            ? null
                                            : resend,
                                        child: Text(
                                          cooldown > 0
                                              ? 'Gửi lại sau ${clock(cooldown)}'
                                              : 'Gửi lại mã',
                                        ),
                                      ),
                                      if (step == AuthStep.reset)
                                        passwordFields(),
                                    ],
                                    if (error != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 14,
                                        ),
                                        child: Semantics(
                                          liveRegion: true,
                                          child: Text(
                                            error!,
                                            style: const TextStyle(
                                              color: Color(0xFFE5484D),
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    FilledButton(
                                      style: step == AuthStep.login
                                          ? FilledButton.styleFrom(
                                              minimumSize: const Size(
                                                double.infinity,
                                                52,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            )
                                          : null,
                                      onPressed:
                                          busy ||
                                              ((step == AuthStep.verify ||
                                                      step == AuthStep.reset) &&
                                                  code.text.length != 6)
                                          ? null
                                          : success
                                          ? () {
                                              password.clear();
                                              go(AuthStep.login);
                                            }
                                          : submit,
                                      child: busy
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  success
                                                      ? 'Đăng nhập ngay'
                                                      : step == AuthStep.login
                                                      ? 'Đăng nhập'
                                                      : step ==
                                                            AuthStep.register
                                                      ? 'Tạo tài khoản'
                                                      : step == AuthStep.verify
                                                      ? 'Xác minh'
                                                      : step == AuthStep.forgot
                                                      ? 'Gửi mã xác minh'
                                                      : 'Đặt lại mật khẩu',
                                                ),
                                                const SizedBox(width: 10),
                                                const Icon(
                                                  Icons.arrow_forward,
                                                  size: 19,
                                                ),
                                              ],
                                            ),
                                    ),
                                    if (!success)
                                      Center(
                                        child: TextButton(
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                            minimumSize: const Size(0, 40),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          onPressed: busy
                                              ? null
                                              : () => go(
                                                  step == AuthStep.login
                                                      ? AuthStep.register
                                                      : AuthStep.login,
                                                ),
                                          child: step == AuthStep.login
                                              ? const Text.rich(
                                                  TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text: 'Chưa có tài khoản? ',
                                                        style: TextStyle(
                                                          color: Color(
                                                            0xFF667085,
                                                          ),
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text: 'Tạo tài khoản',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  textAlign: TextAlign.center,
                                                )
                                              : const Text(
                                                  'Quay lại đăng nhập',
                                                ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(artwork ? 12 : 24),
                          child: Text(
                            'VIỆC NHỎ TRONG TẦM TAY',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2,
                              color: Color(0xFF8BA49A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                if (artwork) {
                  final keyboardOpen =
                      MediaQuery.viewInsetsOf(context).bottom > 0;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: brand,
                              size: 32,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  partnerApp ? 'TaskLy Partner' : 'TaskLy',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: brandDark,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: keyboardOpen
                            ? SingleChildScrollView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                child: content,
                              )
                            : SizedBox.expand(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.bottomCenter,
                                  child: SizedBox(
                                    width: constraints.maxWidth.clamp(
                                      0.0,
                                      480.0,
                                    ),
                                    child: content,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  );
                }
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: content,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class OtpField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;
  const OtpField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    keyboardType: TextInputType.number,
    autofillHints: const [AutofillHints.oneTimeCode],
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(6),
    ],
    onChanged: (_) => onChanged(),
    validator: (v) => (v ?? '').length == 6 ? null : 'Nhập đủ 6 chữ số.',
    style: const TextStyle(
      fontSize: 26,
      letterSpacing: 16,
      fontWeight: FontWeight.w700,
    ),
    textAlign: TextAlign.center,
    decoration: const InputDecoration(labelText: 'Mã xác minh 6 chữ số'),
  );
}
