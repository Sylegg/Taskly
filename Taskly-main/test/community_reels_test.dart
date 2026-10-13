import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/community_reels.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class TestVideoPlatform extends VideoPlayerPlatform {
  final streams = <int, StreamController<VideoEvent>>{};
  final playing = <int>{};
  final disposed = <int>{};
  int nextId = 0;

  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = nextId++;
    streams[id] = StreamController<VideoEvent>()..add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 30),
      size: const Size(360, 640),
    ));
    return id;
  }
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;
  @override
  Future<void> play(int playerId) async { playing.add(playerId); }
  @override
  Future<void> pause(int playerId) async { playing.remove(playerId); }
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    playing.remove(playerId);
    await streams[playerId]!.close();
  }
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      ColoredBox(key: ValueKey('video-${options.playerId}'), color: Colors.black);
}

void main() {
  testWidgets('prepares adjacent reels, preserves pause, and stops in background', (tester) async {
    final previousPlatform = VideoPlayerPlatform.instance;
    final platform = TestVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = previousPlatform);
    final session = Session(api: Api(base: 'http://test/api/v1', client: MockClient((request) async {
      final data = request.url.path.endsWith('/public/community-videos')
          ? List.generate(5, (i) => {'id': '$i', 'videoUrl': '/video/$i.mp4', 'caption': 'Clip $i', 'hashtag': '#test'})
          : {'likes': 0, 'liked': false};
      return http.Response(jsonEncode({'success': true, 'data': data}), 200, headers: {'content-type': 'application/json'});
    })))..access = 'test-token'
      ..expires = DateTime.now().add(const Duration(hours: 1));
    Widget feed() => MaterialApp(home: Scaffold(body: CommunityReels(session: session)));
    await tester.pumpWidget(feed());
    for (var i = 0; i < 8; i++) { await tester.pump(const Duration(milliseconds: 100)); }
    expect(platform.nextId, greaterThanOrEqualTo(2));
    expect(platform.playing, {0});
    await tester.tap(find.byKey(const ValueKey('video-0')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(platform.playing, isEmpty);
    await tester.pumpWidget(feed());
    await tester.pump(const Duration(milliseconds: 700));
    expect(platform.playing, isEmpty);
    await tester.drag(find.byType(PageView), const Offset(0, -700));
    for (var i = 0; i < 8; i++) { await tester.pump(const Duration(milliseconds: 100)); }
    expect(platform.playing, {1});
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(platform.playing, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.playing, {1});
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 8; i++) { await tester.pump(const Duration(milliseconds: 100)); }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(platform.disposed.length, platform.nextId);
    expect(tester.takeException(), isNull);
    session.dispose();
  });
}
