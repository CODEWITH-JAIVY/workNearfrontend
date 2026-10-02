import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _s = FlutterSecureStorage();

  Future<void> saveSession({
    required String access,
    String? refresh,
    String? userType,
    int? userId,
  }) async {
    await _s.write(key: 'access', value: access);
    if (refresh != null) await _s.write(key: 'refresh', value: refresh);
    if (userType != null) await _s.write(key: 'userType', value: userType);
    if (userId != null) await _s.write(key: 'userId', value: '$userId');
  }

  Future<String?> get access => _s.read(key: 'access');
  Future<String?> get refresh => _s.read(key: 'refresh');
  Future<String?> get userType => _s.read(key: 'userType');
  Future<int?> get userId async {
    final v = await _s.read(key: 'userId');
    return v == null ? null : int.tryParse(v);
  }

  Future<void> clear() => _s.deleteAll();
}
