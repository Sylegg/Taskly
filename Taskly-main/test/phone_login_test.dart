import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/auth/auth.dart';

void main() {
  testWidgets(
    'Login validates the identifier and uses the correct portal API',
    (tester) async {
      var calls = 0;
      final session = Session(
        api: Api(
          client: MockClient((request) async {
            calls++;
            expect(request.url.path, '/api/v1/auth/mobile/login-phone');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['phone'], '0901234567');
            expect(body.containsKey('email'), isFalse);
            expect(body['appType'], Session.appType);
            return http.Response(
              jsonEncode({
                'success': false,
                'error': {
                  'code': 'INVALID_CREDENTIALS',
                  'message': 'Invalid credentials',
                },
              }),
              401,
            );
          }),
        ),
      );
      await tester.pumpWidget(MaterialApp(home: AuthPage(session: session)));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .keyboardType,
        TextInputType.phone,
      );
      await tester.enterText(fields.first, 'invalid');
      await tester.enterText(fields.last, 'Password12345');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.enterText(fields.first, '+84 901-234-567');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Invalid credentials'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );
}
