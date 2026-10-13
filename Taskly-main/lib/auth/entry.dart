import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;

import 'api.dart';
import '../main.dart';
import '../features/partner/partner_app.dart';
import 'welcome.dart';

const partnerApp =
    appFlavor == 'partner' ||
    (appFlavor == null && bool.fromEnvironment('PARTNER_APP'));
const brand = partnerApp ? Color(0xFF2563EB) : Color(0xFF16A34A);
const brandDark = partnerApp ? Color(0xFF1D4ED8) : Color(0xFF087A60);
const brandSoft = partnerApp ? Color(0xFFEAF2FF) : Color(0xFFE5F6EC);

class TasklyEntry extends StatefulWidget {
  const TasklyEntry({super.key});
  @override
  State<TasklyEntry> createState() => _TasklyEntryState();
}

class _TasklyEntryState extends State<TasklyEntry> with WidgetsBindingObserver {
  final session = Session();
  Timer? reconnectTimer;
  bool appActive = true;
  StreamSubscription<void>? liveSubscription;

  void scheduleReconnect() {
    if (session.user == null) {
      liveSubscription?.cancel();
      liveSubscription = null;
    } else {
      liveSubscription ??= session.liveChanges.listen((_) => checkConnection());
    }
    reconnectTimer?.cancel();
    if (!appActive || session.loading || session.restoreError == null) return;
    reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (mounted &&
          appActive &&
          !session.loading &&
          session.restoreError != null) {
        session.restore();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session.addListener(scheduleReconnect);
    session.restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    reconnectTimer?.cancel();
    session.removeListener(scheduleReconnect);
    liveSubscription?.cancel();
    session.dispose();
    super.dispose();
  }

  Future<void> checkConnection() async {
    if (session.user == null) return;
    try {
      await session.syncUser();
    } catch (_) {
      /* Keep the current profile and home snapshot. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appActive = state == AppLifecycleState.resumed;
    reconnectTimer?.cancel();
    if (appActive) {
      if (session.restoreError != null && !session.loading) {
        session.restore();
      } else {
        checkConnection();
        scheduleReconnect();
      }
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: partnerApp ? 'TaskLy Partner' : 'TaskLy',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: brand, primary: brand),
      scaffoldBackgroundColor: partnerApp
          ? const Color(0xFFF5F8FF)
          : const Color(0xFFF7FBF9),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFAFCFB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brand),
      ),
    ),
    home: ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (session.restoreError != null) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    const Text('Đang kết nối lại TaskLy...'),
                    const SizedBox(height: 8),
                    const Text('App sẽ tự vào khi kết nối thành công.'),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: session.logout,
                      child: const Text('Đăng nhập tài khoản khác'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return session.user == null
            ? GuestEntry(session: session)
            : partnerApp
            ? PartnerApp(
                key: ValueKey(session.user!['id']),
                session: session,
                onLogout: session.logout,
              )
            : TaskLyApp(
                key: ValueKey(session.user!['id']),
                apiSession: session,
                user: session.user,
                onLogout: session.logout,
                homeOffline: session.offline,
                onHomeRetry: checkConnection,
                isPartner: false,
              );
      },
    ),
  );
}
