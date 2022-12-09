import 'package:actual/common/const/data.dart';
import 'package:actual/common/secure_storage/secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();

  final storage = ref.watch(secureStorageProvider);

  dio.interceptors.add(
    CustomInterceptor(storage: storage),
  );

  return dio;
});

class CustomInterceptor extends Interceptor {
  final FlutterSecureStorage storage;

  CustomInterceptor({
    required this.storage,
  });

  // 1) 요청을 보낼 때
  // 요청이 보내질 때마다, 요청 Header에 accessToken : true 값이 있다면,
  // storage에서 실제 토큰을 가져와서 authorization : bearer $token으로 헤더를 변경한다.
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    print('[REQ] [${options.method}] [${options.uri}]');

    if (options.headers['accessToken'] == 'true') {
      options.headers.remove('accessToken');

      final token = await storage.read(key: ACCESS_TOKEN_KEY);
      options.headers.addAll({
        'authorization': 'Bearer $token',
      });
    }

    if (options.headers['refreshToken'] == 'true') {
      options.headers.remove('refreshToken');

      final token = await storage.read(key: REFRESH_TOKEN_KEY);
      options.headers.addAll({
        'authorization': 'Bearer $token',
      });
    }

    return super.onRequest(options, handler);
  }

  // 2) 응답을 받을 때
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print(
        '[RES] [${response.requestOptions.method}] [${response.requestOptions.uri}]');
    return super.onResponse(response, handler);
  }

  // 3) 에러가 났을 때
  @override
  void onError(DioError err, ErrorInterceptorHandler handler) async {
    // 401 에러가 났을 때, 토큰을 재발급 받는 시도를 하고 토큰이 재발급되면 다시 새로운 토큰으로 요청
    print('[ERR] [${err.requestOptions.method}] [${err.requestOptions.uri}]');

    final refreshToken = await storage.read(key: REFRESH_TOKEN_KEY);
    // refreshToken이 아예 없으면 에러를 던진다.
    if (refreshToken == null) {
      return handler.reject(err); // 에러를 그대로 반환
    }

    final isStatus401 = err.response?.statusCode == 401;
    final isPathRefresh = err.requestOptions.path == '/auth/token';

    if (isStatus401 && !isPathRefresh) {
      final dio = Dio();
      try {
        final resp = await dio.post('http://$ip/auth/token',
            options: Options(headers: {
              'authorization': 'Bearer $refreshToken',
            }));
        final accessToken = resp.data['accessToken'];

        final options = err.requestOptions;
        options.headers.addAll({
          'authorization': 'Bearer $accessToken',
        });

        // 토큰 변경하기
        await storage.write(key: ACCESS_TOKEN_KEY, value: accessToken);

        final response = await dio.fetch(options); // 요청 재전송 및 응답 받기

        return handler.resolve(response); // 응답과 함께 요청이 성공했다고 반환
      } on DioError catch (e) {
        return handler.reject(e);
      }
    }

    return handler.reject(err);
  }
}
