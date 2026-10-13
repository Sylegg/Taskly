import 'package:flutter/material.dart';

import 'auth/entry.dart';
import 'auth/api.dart';
import 'data/api_customer_repository.dart';
import 'domain/models.dart';

import 'app/customer_controller.dart';
import 'app/dependencies.dart';
import 'app/tasker_controller.dart';
import 'core/theme.dart';
import 'features/customer_view.dart';
import 'features/tasker_view.dart';
import 'features/partner/recruitment_shell.dart';
import 'data/mock/mock_data_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TasklyEntry());
}

class TaskLyApp extends StatefulWidget {
  const TaskLyApp({
    super.key,
    this.controller,
    this.taskerController,
    this.user,
    this.onLogout,
    this.isPartner = partnerApp,
    this.allowRoleSwitch = false,
    this.homeOffline = false,
    this.onHomeRetry,
    this.apiSession,
  });
  final bool isPartner;
  final Session? apiSession;
  final bool homeOffline;
  final Future<void> Function()? onHomeRetry;
  // Only the shared-session test harness needs both portals in one app.
  final bool allowRoleSwitch;
  final Map<String, dynamic>? user;
  final Future<void> Function()? onLogout;
  final CustomerController? controller;
  final TaskerController? taskerController;
  @override
  State<TaskLyApp> createState() => _TaskLyAppState();
}

class _TaskLyAppState extends State<TaskLyApp> {
  final session = MockDataStore();
  late final CustomerController controller =
      widget.controller ??
      (widget.apiSession == null
          ? createCustomerController(store: session)
          : CustomerController(ApiCustomerRepository(widget.apiSession!)));
  late final TaskerController taskerController =
      widget.taskerController ?? createTaskerController(store: session);
  late bool taskerMode = widget.isPartner;
  @override
  void initState() {
    super.initState();
    final user = widget.user;
    if (user != null) {
      final profile = Profile(
        user['fullName']?.toString() ?? '',
        user['phone']?.toString() ?? '',
        user['email']?.toString() ?? '',
        '',
      );
      if (widget.isPartner) {
        session.taskerAuthenticated = true;
        session.taskerProfile = session.taskerProfile.copy(profile: profile);
        taskerController.root(TaskerPage.home);
      } else {
        session.authenticated = true;
        session.profile = profile;
        controller.root(PageId.home);
      }
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      controller.dispose();
    }
    if (widget.taskerController == null) {
      taskerController.dispose();
    }
    super.dispose();
    session.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: widget.isPartner ? 'TaskLy Partner' : 'TaskLy Customer',
    debugShowCheckedModeBanner: false,
    theme: taskerMode ? AppTheme.partner : AppTheme.light,
    home: taskerMode
        ? widget.apiSession != null
              ? RecruitmentShell(
                  session: widget.apiSession!,
                  onLogout: widget.onLogout,
                )
              : TaskerView(
                  controller: taskerController,
                  onLogout: widget.onLogout,
                  onSwitchCustomer:
                      widget.allowRoleSwitch && taskerController.demoMode
                      ? () {
                          controller.refresh();
                          setState(() => taskerMode = false);
                        }
                      : null,
                )
        : CustomerView(
            homeOffline: widget.homeOffline,
            onHomeRetry: widget.onHomeRetry,
            controller: controller,
            onLogout: widget.onLogout,
            onOpenTasker: widget.allowRoleSwitch && widget.apiSession == null
                ? () {
                    if (taskerController.demoMode) {
                      taskerController.refresh();
                    }
                    setState(() => taskerMode = true);
                  }
                : null,
          ),
  );
}
