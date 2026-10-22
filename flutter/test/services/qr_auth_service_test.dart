import 'dart:convert';

import 'package:family_toktok/services/api_client.dart';
import 'package:family_toktok/services/qr_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late List<http.Request> requests;

  ApiClient clientReturning(int status, Object body) {
    requests = [];
    return ApiClient(
      baseUrl: 'http://localhost:4000',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(body), status,
            headers: {'content-type': 'application/json'});
      }),
      accessTokenProvider: () async => 'jwt-123',
    );
  }

  group('QrAuthService.issue', () {
    test('POST /auth/qr/issue에 kidMemberId + Bearer 토큰을 보내고 결과를 파싱한다',
        () async {
      final service = QrAuthService(clientReturning(201, {
        'token': 'secret-token',
        'shortCode': '482913',
        'expiresAt': '2026-10-22T03:02:00.000Z',
      }));

      final result = await service.issue('kid-uuid');

      expect(result.token, 'secret-token');
      expect(result.shortCode, '482913');
      expect(result.expiresAt, DateTime.parse('2026-10-22T03:02:00.000Z'));

      final req = requests.single;
      expect(req.method, 'POST');
      expect(req.url.toString(), 'http://localhost:4000/auth/qr/issue');
      expect(req.headers['Authorization'], 'Bearer jwt-123');
      expect(jsonDecode(req.body), {'kidMemberId': 'kid-uuid'});
    });

    test('토큰 문자열이 toString()에 노출되지 않는다 (로그 유출 방지)', () async {
      final service = QrAuthService(clientReturning(201, {
        'token': 'secret-token',
        'shortCode': '482913',
        'expiresAt': '2026-10-22T03:02:00.000Z',
      }));

      final result = await service.issue('kid-uuid');

      expect(result.toString(), isNot(contains('secret-token')));
    });

    test('다른 가족 아이면 404 ApiError', () async {
      final service = QrAuthService(clientReturning(
          404, {'error': 'kid member not found in your family'}));

      await expectLater(
        service.issue('other-kid'),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 404)),
      );
    });
  });
}
