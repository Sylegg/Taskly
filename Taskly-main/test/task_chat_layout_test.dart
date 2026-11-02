import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/task_chat.dart';

class ChatSession extends Session {
  String? requestedPath;
  String? postedPath;
  Map<String, dynamic>? postedBody;
  @override
  Stream<void> get liveChanges => const Stream.empty();
  @override
  Future<dynamic> request(String path, {String method = 'GET', Map<String, dynamic>? body}) async {
    if (method == 'POST') {
      postedPath = path;
      postedBody = body;
      return null;
    }
    requestedPath = path;
    return {
      'task': {
        'id': 'task-12345678',
        'status': 'ACCEPTED',
        'serviceName': 'Dọn dẹp nhà',
        'taskerName': 'Tasker Nam',
        'customerName': 'Chị Hoa',
      },
      'messages': [
        {'id': 'own', 'text': 'My message', 'mine': true},
        {'id': 'other', 'text': 'Their message', 'mine': false},
      ],
    };
  }
}
void main() {
  for (final partner in [false, true]) {
    testWidgets('Chat positions and colors for partner=$partner', (tester) async {
      final session = ChatSession();
      await tester.pumpWidget(MaterialApp(home: TaskChatScreen(session: session, taskId: 'task', partner: partner)));
      await tester.pump();
      expect(session.requestedPath, '/task-activity/task?partner=$partner');
      final own = find.text('My message');
      final other = find.text('Their message');
      Align alignment(Finder text) => tester.widget<Align>(find.ancestor(of: text, matching: find.byType(Align)).first);
      BoxDecoration decoration(Finder text) => tester.widget<Container>(find.ancestor(of: text, matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration)).first).decoration! as BoxDecoration;
      expect(alignment(own).alignment, Alignment.centerRight);
      expect(alignment(other).alignment, Alignment.centerLeft);
      expect(decoration(own).color, Colors.white);
      expect(decoration(other).color, const Color(0xFF059669));
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
  }

  testWidgets('Customer chat displays Tasker info and sends with partner=false', (tester) async {
    final session = ChatSession();
    await tester.pumpWidget(MaterialApp(
      home: TaskChatScreen(session: session, taskId: 'task-12345678', partner: false),
    ));
    await tester.pump();

    expect(find.text('Tasker Nam'), findsOneWidget);
    expect(find.textContaining('Tasker Đối tác'), findsOneWidget);
    expect(find.text('Nhắn tin cho Tasker...'), findsOneWidget);
    expect(find.text('📍 Xác nhận địa chỉ'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Chào bạn tasker');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(session.postedPath, '/task-activity/task-12345678/messages?partner=false');
    expect(session.postedBody?['text'], 'Chào bạn tasker');

    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('Partner chat displays Customer info and sends with partner=true', (tester) async {
    final session = ChatSession();
    await tester.pumpWidget(MaterialApp(
      home: TaskChatScreen(session: session, taskId: 'task-12345678', partner: true),
    ));
    await tester.pump();

    expect(find.text('Chị Hoa'), findsOneWidget);
    expect(find.textContaining('Khách hàng'), findsOneWidget);
    expect(find.text('Nhắn tin cho khách hàng...'), findsOneWidget);
    expect(find.text('🛵 Đang trên đường đến'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Chào chị Hoa');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(session.postedPath, '/task-activity/task-12345678/messages?partner=true');
    expect(session.postedBody?['text'], 'Chào chị Hoa');

    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
