import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/io.dart';
import '../features/auth/auth_controller.dart';
import 'api_client.dart';
import 'config.dart';
import 'token_storage.dart';

class AppEvent {
  final String type;
  final Map<String, dynamic> data;
  AppEvent(this.type, this.data);
}

/// One notification WebSocket per logged-in user, auto-reconnect with backoff.
/// Server events: NEW_JOB_AVAILABLE {jobId}  |  JOB_ACCEPTED {jobId, labourId}
class SocketService {
  SocketService(this._storage, this._userId);
  final TokenStorage _storage;
  final int? _userId;
  final _ctrl = StreamController<AppEvent>.broadcast();
  IOWebSocketChannel? _ch;
  bool _closed = false;
  int _retry = 0;

  Stream<AppEvent> get events => _ctrl.stream;

  Future<void> connect() async {
    if (_closed || _userId == null) return;
    try {
      final token = await _storage.access;
      final ch = IOWebSocketChannel.connect(
        Uri.parse('${Config.wsBase}/ws/notifications?userId=$_userId'),
        headers: {'Authorization': 'Bearer $token'}, // gateway validates JWT on the upgrade request
        pingInterval: const Duration(seconds: 30),
      );
      _ch = ch;
      await ch.ready;
      _retry = 0;
      ch.stream.listen(
        (raw) {
          try {
            final m = jsonDecode(raw as String) as Map<String, dynamic>;
            _ctrl.add(AppEvent(m['type'] as String, m));
          } catch (_) {}
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('WS connect failed: $e');
      await refreshTokens(_storage); // most likely an expired access token
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_closed) return;
    final secs = 2 << (_retry++).clamp(0, 5).toInt(); // 2,4,8,..64s
    Future.delayed(Duration(seconds: secs), connect);
  }

  void dispose() {
    _closed = true;
    _ch?.sink.close();
    _ctrl.close();
  }
}

final socketProvider = Provider<SocketService>((ref) {
  final uid = ref.watch(authProvider.select((a) => a.value?.userId));
  final s = SocketService(ref.read(tokenStorageProvider), uid);
  if (uid != null) s.connect();
  ref.onDispose(s.dispose);
  return s;
});

final eventsProvider = StreamProvider<AppEvent>((ref) => ref.watch(socketProvider).events);
