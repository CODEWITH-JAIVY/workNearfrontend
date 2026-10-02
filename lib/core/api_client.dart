import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config.dart';
import 'token_storage.dart';

final tokenStorageProvider = Provider((_) => TokenStorage());

/// Bumped when refresh fails -> AuthController logs the user out.
final authLostProvider = StateProvider<int>((_) => 0);

/// POST /api/auth/refresh?refreshToken=...  (backend takes a query param, not a body)
Future<String?> refreshTokens(TokenStorage s) async {
  final r = await s.refresh;
  if (r == null || r.isEmpty) return null;
  try {
    final res = await Dio(BaseOptions(baseUrl: Config.baseUrl))
        .post('/api/auth/refresh', queryParameters: {'refreshToken': r});
    final d = res.data as Map;
    await s.saveSession(
      access: d['accessToken'],
      refresh: (d['refreshToken'] as String?) ?? r,
      userType: d['userType'] as String?,
      userId: (d['userId'] as num?)?.toInt(),
    );
    return d['accessToken'] as String;
  } catch (_) {
    return null;
  }
}

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(tokenStorageProvider);
  final dio = Dio(BaseOptions(
    baseUrl: Config.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  dio.interceptors.add(QueuedInterceptorsWrapper(
    onRequest: (o, h) async {
      final t = await storage.access;
      if (t != null) o.headers['Authorization'] = 'Bearer $t';
      h.next(o);
    },
    onError: (e, h) async {
      final req = e.requestOptions;
      final is401 = e.response?.statusCode == 401;
      if (is401 && req.extra['retried'] != true && !req.path.startsWith('/api/auth/')) {
        final newAccess = await refreshTokens(storage);
        if (newAccess == null) {
          ref.read(authLostProvider.notifier).state++;
          return h.next(e);
        }
        req.extra['retried'] = true;
        req.headers['Authorization'] = 'Bearer $newAccess';
        try {
          return h.resolve(await dio.fetch(req));
        } on DioException catch (e2) {
          return h.next(e2);
        }
      }
      h.next(e);
    },
  ));
  return dio;
});

String apiError(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
    if (e.response?.statusCode == 409) return 'Already taken / conflict';
    return e.message ?? 'Network error';
  }
  return e.toString();
}
