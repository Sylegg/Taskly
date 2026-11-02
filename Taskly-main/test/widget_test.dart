import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/auth/auth.dart';
import 'package:taskly_mobile/auth/welcome.dart';

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final outcome in ['success', 'timeout', 'cooldown', 'delayed']) {
    testWidgets('Registration opens OTP after $outcome', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final delayedReply = Completer<http.Response>();
      final api = Api(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/register')) {
            if (outcome == 'delayed') return delayedReply.future;
            if (outcome == 'timeout') {
              throw TimeoutException('Delayed response');
            }
            if (outcome == 'cooldown') {
              return http.Response(
                jsonEncode({
                  'success': false,
                  'error': {'code': 'OTP_RATE_LIMITED', 'message': 'Wait'},
                }),
                429,
              );
            }
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'status': 'PENDING_VERIFICATION'},
              }),
              200,
            );
          }
          expect(request.url.path, '/api/v1/auth/verify-otp');
          expect(jsonDecode(request.body)['code'], '123456');
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );
      final session = Session(api: api);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthPage(session: session, initialStep: AuthStep.register),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Test customer');
      await tester.enterText(fields.at(1), 'customer@gmail.com');
      await tester.enterText(fields.at(2), '0901234567');
      await tester.enterText(fields.at(3), 'Password12345');
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.byType(FilledButton));
      if (outcome == 'delayed') {
        await tester.pump();
        expect(find.byType(OtpField), findsOneWidget);
        expect(find.textContaining('Đang gửi mã xác minh'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        delayedReply.complete(
          http.Response(
            jsonEncode({
              'success': true,
              'data': {'status': 'PENDING_VERIFICATION'},
            }),
            200,
          ),
        );
      }
      await tester.pumpAndSettle();
      expect(find.byType(OtpField), findsOneWidget);
      expect(
        tester.getRect(find.byType(FilledButton)).bottom,
        greaterThan(700),
      );
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Xác minh thành công!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
  }
  for (final register in [true, false]) {
    testWidgets('Welcome opens ${register ? "register" : "login"}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = Session();
      await tester.pumpWidget(MaterialApp(home: GuestEntry(session: session)));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomePage), findsOneWidget);
      final action = register
          ? find.text('Đăng ký ngay')
          : find.textContaining('Đã có tài khoản?', findRichText: true);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomePage), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(register ? 4 : 2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
  }
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('Register stays on one screen at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = Session();
      await tester.pumpWidget(MaterialApp(home: AuthPage(session: session)));
      await tester.pumpAndSettle();
      final register = find.textContaining(
        'Chưa có tài khoản?',
        findRichText: true,
      );
      await tester.ensureVisible(register);
      await tester.tap(register);
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(find.byType(SingleChildScrollView), findsNothing);
      final buttonRect = tester.getRect(find.byType(FilledButton));
      final backRect = tester.getRect(find.text('Quay lại đăng nhập'));
      expect(buttonRect.bottom, lessThanOrEqualTo(size.height));
      expect(backRect.bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
    testWidgets('Auth fits $size and validates email', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = Session();
      await tester.pumpWidget(MaterialApp(home: AuthPage(session: session)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = find.byType(FilledButton);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
  }
}
