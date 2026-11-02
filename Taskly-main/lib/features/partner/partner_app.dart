import 'package:flutter/material.dart';

import '../../auth/api.dart';
import '../../core/theme.dart';
import 'recruitment_shell.dart';

/// Production Partner portal has no Customer or legacy demo navigation.
class PartnerApp extends StatelessWidget {
  const PartnerApp({super.key, required this.session, this.onLogout});
  final Session session;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TaskLy Partner',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.partner,
    home: RecruitmentShell(session: session, onLogout: onLogout),
  );
}
