import 'dart:convert';

import 'package:http/http.dart' as http;

/// backend REST 호출 실패. RN `frontend/services/api.ts`의 ApiError에 대응.
class ApiError implements Exception {
  const ApiError(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => 'ApiError($status): $message';
}

/// 현재 Supabase 세션의 access token(JWT)을 돌려준다. 세션이 없으면 null.
typedef AccessTokenProvider = Future<String?> Function();

/// backend(Express) REST 래퍼. 가족 생성/초대/아이 추가/QR 로그인만 이 경로를 쓴다 (ADR-004).
/// 일상 데이터(대화/기분/칭찬)는 Supabase를 직접 호출하므로 여기에 추가하지 않는다.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required http.Client httpClient,
    required AccessTokenProvider accessTokenProvider,
  })  : _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _http = httpClient,
        _accessToken = accessTokenProvider;

  final String _baseUrl;
  final http.Client _http;
  final AccessTokenProvider _accessToken;

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    bool auth = true,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await _accessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final response = await _http.post(
      Uri.parse('$_baseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    );

    final json = _decodeObject(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      throw ApiError(
        response.statusCode,
        error is String ? error : 'request failed (${response.statusCode})',
      );
    }
    return json;
  }

  static Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }
}
