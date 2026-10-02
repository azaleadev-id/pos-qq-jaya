import 'package:dio/dio.dart';
import '../lib/core/network/infinity_free_challenge.dart';

Future<void> main(List<String> args) async {
  final path = args.isEmpty ? '/schema_probe.php' : args.first;
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://qq-jaya-api.unaux.com',
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
      headers: {
        'Accept': 'application/json,text/html,*/*',
        'X-API-Key': 'qq-jaya-cell-local-key',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/154.0.0.0 Safari/537.36',
      },
    ),
  );

  String? cookie;
  for (var attempt = 0; attempt < 3; attempt++) {
    final response = await dio.get<String>(
      path,
      queryParameters: attempt == 0 ? null : {'i': attempt},
      options: Options(
        headers: cookie == null || cookie.isEmpty
            ? null
            : {'Cookie': '__test=$cookie'},
      ),
    );
    final body = response.data ?? '';
    if (InfinityFreeChallenge.isChallenge(body)) {
      cookie = InfinityFreeChallenge.solveCookie(body);
      continue;
    }
    print(body);
    return;
  }
  throw StateError('Challenge did not resolve.');
}
