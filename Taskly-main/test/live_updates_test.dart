import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/auth/live_updates.dart';

void main() {
  testWidgets('one connection serves listeners, pauses and resyncs on resume', (tester) async {
    final requests = <Completer<dynamic>>[];
    final sync = LiveUpdates((path) {
      final pending = Completer<dynamic>(); requests.add(pending); return pending.future;
    });
    var first = 0, second = 0;
    final a = sync.changes.listen((_) => first++);
    final b = sync.changes.listen((_) => second++);
    expect(requests.length, 1);
    requests.first.complete({'revision': 1});
    await tester.pump();
    expect(first, 1); expect(second, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(requests.length, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    requests[1].complete({'revision': 2});
    await tester.pump(const Duration(seconds: 10));
    expect(requests.length, 2); expect(first, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(first, 2); expect(requests.length, 3);
    requests[2].complete({'revision': 3}); await tester.pump();
    expect(first, 3); expect(second, 3);
    unawaited(a.cancel()); unawaited(b.cancel()); sync.dispose();
    await tester.pump(const Duration(seconds: 10));
    expect(requests.length, 3);
  });
}
