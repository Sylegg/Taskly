import 'dart:async';
import 'package:flutter/widgets.dart';

/// One authenticated long-poll connection shared by all screens in a session.
class LiveUpdates with WidgetsBindingObserver {
  LiveUpdates(this.request) {
    _events = StreamController<void>.broadcast(onListen: _start, onCancel: _stop);
    WidgetsBinding.instance.addObserver(this);
  }
  final Future<dynamic> Function(String path) request;
  late final StreamController<void> _events;
  Stream<void> get changes => _events.stream;
  Timer? _retry;
  bool _disposed = false, _running = false;
  int _epoch = 0;
  int? _revision;
  DateTime _lastRefresh = DateTime.now();
  bool get _active => WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  void _stop() { _epoch++; _running = false; _retry?.cancel(); }
  void _start() {
    if (_disposed || _running || !_active || !_events.hasListener) return;
    _running = true;
    final epoch = ++_epoch;
    unawaited(_poll(epoch));
  }
  Future<void> _poll(int epoch) async {
    var delay = const Duration(seconds: 1);
    try {
      final data = await request('/live-sync?since=${_revision ?? -1}');
      if (_disposed || epoch != _epoch) return;
      final next = data is Map ? data['revision'] : null;
      if (next is! num) throw const FormatException('Invalid live revision');
      final revision = next.toInt();
      if (_revision != revision || DateTime.now().difference(_lastRefresh).inSeconds >= 30) {
        _revision = revision;
        _lastRefresh = DateTime.now();
        _events.add(null);
      }
    } catch (_) {
      delay = const Duration(seconds: 5);
      if (!_disposed && epoch == _epoch && DateTime.now().difference(_lastRefresh).inSeconds >= 30) {
        _lastRefresh = DateTime.now();
        _events.add(null);
      }
    } finally {
      if (!_disposed && epoch == _epoch) {
        _running = false;
        _retry = Timer(delay, _start);
      }
    }
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    _stop();
    if (state == AppLifecycleState.resumed && !_disposed && _events.hasListener) {
      _events.add(null);
      _start();
    }
  }
  void dispose() {
    _disposed = true; _stop();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_events.close());
  }
}
