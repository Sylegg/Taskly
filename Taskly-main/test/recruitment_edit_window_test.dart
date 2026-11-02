import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/recruitment_identity.dart';

void main() {
  for (final scenario in ['amendment', 'expired', 'draft']) {
    testWidgets('identity $scenario preserves saved evidence and edit limits', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var writes = 0;
      final verification = <String, dynamic>{
        'id': 'identity',
        'status': scenario == 'draft' ? 'DRAFT' : 'SUBMITTED',
        'legalName': 'Tên đã lưu',
        'documentType': 'NATIONAL_ID',
        if (scenario != 'draft') 'documentNumberMasked': '********7890',
        'documents': [
          {'id': 'front', 'side': 'FRONT', 'scanStatus': 'CLEAN'},
          {'id': 'back', 'side': 'BACK', 'scanStatus': 'CLEAN'},
        ],
      };
      final session =
          Session(
              api: Api(
                base: 'http://test/api/v1',
                client: MockClient((request) async {
                  Object data;
                  if (request.url.path.endsWith('/draft')) {
                    expect(request.method, 'PATCH');
                    final body = jsonDecode(request.body);
                    expect(body['legalName'], 'Họ tên đã bổ sung');
                    expect(body['documentNumber'], '');
                    verification['legalName'] = body['legalName'];
                    writes++;
                    data = verification;
                  } else {
                    data = switch (request.url.path) {
                      '/api/v1/users/me/modes/tasker' => <String, dynamic>{},
                      '/api/v1/verifications/me' => verification,
                      '/api/v1/partner/onboarding' => {
                        'status': scenario == 'draft'
                            ? 'PROFILE_INCOMPLETE'
                            : 'PRELIMINARY_REVIEW',
                        'editable': scenario != 'expired',
                        if (scenario != 'draft')
                          'editableUntil': DateTime.now()
                              .add(
                                Duration(hours: scenario == 'expired' ? -1 : 1),
                              )
                              .toUtc()
                              .toIso8601String(),
                      },
                      _ => throw StateError('Unexpected ${request.url.path}'),
                    };
                  }
                  return http.Response(
                    jsonEncode({'success': true, 'data': data}),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
                }),
              ),
            )
            ..access = 'fixture'
            ..expires = DateTime.now().add(const Duration(hours: 1));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecruitmentIdentity(session: session),
                  ),
                ),
                child: const Text('Mở hồ sơ'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở hồ sơ'));
      await tester.pumpAndSettle();
      if (scenario == 'expired') {
        expect(find.byType(TextFormField), findsNothing);
        expect(find.text('Lưu bổ sung hồ sơ'), findsNothing);
        expect(writes, 0);
      } else {
        expect(find.textContaining('Đã tải ảnh lên'), findsNWidgets(2));
        await tester.enterText(
          find.byType(TextFormField).first,
          'Họ tên đã bổ sung',
        );
        final save = find.text(
          scenario == 'draft' ? 'Lưu nháp và thoát' : 'Lưu bổ sung hồ sơ',
        );
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(writes, 1);
        expect(verification['legalName'], 'Họ tên đã bổ sung');
        expect(
          verification['status'],
          scenario == 'draft' ? 'DRAFT' : 'SUBMITTED',
        );
        expect(find.text('Mở hồ sơ'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      session.dispose();
    });
  }
}
