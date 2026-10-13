import 'package:flutter/material.dart';

import 'api.dart';
import 'auth.dart';
import 'entry.dart';

class GuestEntry extends StatefulWidget {
  final Session session;
  const GuestEntry({super.key, required this.session});

  @override
  State<GuestEntry> createState() => _GuestEntryState();
}

class _GuestEntryState extends State<GuestEntry> {
  AuthStep? selectedStep;

  @override
  Widget build(BuildContext context) {
    if (selectedStep != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) setState(() => selectedStep = null);
        },
        child: AuthPage(session: widget.session, initialStep: selectedStep!),
      );
    }
    return WelcomePage(
      onRegister: () => setState(() => selectedStep = AuthStep.register),
      onLogin: () => setState(() => selectedStep = AuthStep.login),
    );
  }
}

class WelcomePage extends StatelessWidget {
  final VoidCallback onRegister;
  final VoidCallback onLogin;
  const WelcomePage({
    super.key,
    required this.onRegister,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/nendangnhap.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: brand, size: 32),
                    SizedBox(width: 8),
                    Text(
                      partnerApp ? 'TaskLy Partner' : 'TaskLy',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: brandDark,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: Alignment.bottomCenter,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 448),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'VIỆC NHỎ TRONG TẦM TAY',
                                  style: TextStyle(
                                    color: brand,
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Chào mừng bạn\nđến với TaskLy',
                                  style: TextStyle(
                                    fontSize: 30,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Khám phá dịch vụ cho cuộc sống hằng ngày. Tạo tài khoản để bắt đầu cùng TaskLy.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const _Benefit(
                                  icon: Icons.home_outlined,
                                  title: 'Dịch vụ quanh bạn',
                                  detail: 'Tìm hiểu các dịch vụ phù hợp với nhu cầu.',
                                ),
                                const SizedBox(height: 12),
                                const _Benefit(
                                  icon: Icons.person_outline,
                                  title: 'Tài khoản của riêng bạn',
                                  detail: 'Quản lý thông tin cá nhân trong một nơi.',
                                ),
                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed: onRegister,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Đăng ký ngay'),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward, size: 20),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Center(
                                  child: TextButton(
                                    onPressed: onLogin,
                                    child: const Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Đã có tài khoản? ',
                                            style: TextStyle(
                                              color: Color(0xFF667085),
                                            ),
                                          ),
                                          TextSpan(
                                            text: 'Đăng nhập',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
            ],
          ),
        ),
      ],
    ),
  );
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  const _Benefit({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF8EE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: brand, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
