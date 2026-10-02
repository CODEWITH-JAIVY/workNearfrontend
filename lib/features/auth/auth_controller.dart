import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/token_storage.dart';

class Session {
  final String? userType; // CUSTOMER | LABOUR | ADMIN | PENDING | null
  final int? userId;
  const Session({this.userType, this.userId});
  bool get needsRole => userType == null || userType == 'PENDING';
  bool get isLabour => userType == 'LABOUR';
}

Map<String, dynamic> jwtClaims(String t) {
  final p = base64Url.normalize(t.split('.')[1]);
  return jsonDecode(utf8.decode(base64Url.decode(p))) as Map<String, dynamic>;
}

final authProvider = AsyncNotifierProvider<AuthController, Session?>(AuthController.new);

class AuthController extends AsyncNotifier<Session?> {
  TokenStorage get _s => ref.read(tokenStorageProvider);

  @override
  Future<Session?> build() async {
    ref.listen(authLostProvider, (_, __) => logout());
    if (await _s.access == null) return null;
    return Session(userType: await _s.userType, userId: await _s.userId);
  }

  // AuthResponse = {accessToken, refreshToken, userId, userType}
  Future<Session> _fromResponse(dynamic d) async {
    final type = d['userType'] as String?;
    final id = (d['userId'] as num?)?.toInt();
    await _s.saveSession(
        access: d['accessToken'], refresh: d['refreshToken'], userType: type, userId: id);
    return Session(userType: type, userId: id);
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final r = await ref
          .read(dioProvider)
          .post('/api/auth/login', data: {'email': email, 'password': password});
      return _fromResponse(r.data);
    });
  }

  Future<void> signup(String email, String mobile, String password, String userType) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final r = await ref.read(dioProvider).post('/api/auth/signup', data: {
        'email': email, 'mobile': mobile, 'password': password, 'userType': userType,
      });
      return _fromResponse(r.data);
    });
  }

  /// Google: opens backend /oauth2/authorization/google in a Custom Tab; backend then redirects to
  /// worknear://auth/select-role?token=...  (new user)  or  /oauth-success?token=..&refreshToken=..
  Future<void> google() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final res = await FlutterWebAuth2.authenticate(
        url: '${Config.baseUrl}/oauth2/authorization/google',
        callbackUrlScheme: Config.authScheme,
      );
      final q = Uri.parse(res).queryParameters;
      final access = q['token'];
      if (access == null) throw 'Google sign-in failed';
      final c = jwtClaims(access);
      final type = c['role'] as String?; // PENDING until select-role
      final id = int.tryParse('${c['sub']}');
      await _s.saveSession(access: access, refresh: q['refreshToken'], userType: type, userId: id);
      return Session(userType: type, userId: id);
    });
  }

  /// POST /api/auth/select-role {userType}; returns fresh tokens with the real role.
  Future<void> selectRole(String userType) async {
    final r = await ref.read(dioProvider).post('/api/auth/select-role', data: {'userType': userType});
    state = AsyncData(await _fromResponse(r.data));
  }

  Future<void> logout() async {
    await _s.clear();
    state = const AsyncData(null);
  }
}
