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

  group('QrAuthService redeem (아이 기기)', () {
    late List<(String, String)> applied;

    QrAuthService serviceReturning(int status, Object body) {
      applied = [];
      return QrAuthService(
        clientReturning(status, body),
        applySession: (access, refresh) async => applied.add((access, refresh)),
      );
    }

    const ok = {
      'accessToken': 'access-abc',
      'refreshToken': 'refresh-xyz',
      'authUserId': 'kid-auth-uuid',
    };

    test('redeemQrToken: Bearer 없이 POST /auth/qr/redeem 후 세션을 적용한다',
        () async {
      final service = serviceReturning(200, ok);

      await service.redeemQrToken('scanned-token');

      final req = requests.single;
      expect(req.url.toString(), 'http://localhost:4000/auth/qr/redeem');
      expect(req.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(req.body), {'token': 'scanned-token'});
      expect(applied, [('access-abc', 'refresh-xyz')]);
    });

    test('redeemShortCode: Bearer 없이 POST /auth/code/redeem 후 세션을 적용한다',
        () async {
      final service = serviceReturning(200, ok);

      await service.redeemShortCode('482913');

      final req = requests.single;
      expect(req.url.toString(), 'http://localhost:4000/auth/code/redeem');
      expect(req.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(req.body), {'shortCode': '482913'});
      expect(applied, [('access-abc', 'refresh-xyz')]);
    });

    for (final status in [404, 409, 410]) {
      test('redeemQrToken: $status면 ApiError를 던지고 세션을 건드리지 않는다',
          () async {
        final service = serviceReturning(status, {'error': 'x'});

        await expectLater(
          service.redeemQrToken('t'),
          throwsA(isA<ApiError>().having((e) => e.status, 'status', status)),
        );
        expect(applied, isEmpty);
      });
    }

    test('redeemShortCode: 429(본문이 JSON이 아니어도)면 ApiError(429)', () async {
      requests = [];
      applied = [];
      final service = QrAuthService(
        ApiClient(
          baseUrl: 'http://localhost:4000',
          httpClient: MockClient((r) async =>
              http.Response('Too many requests, please try again later.', 429)),
          accessTokenProvider: () async => null,
        ),
        applySession: (a, r) async => applied.add((a, r)),
      );

      await expectLater(
        service.redeemShortCode('482913'),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 429)),
      );
      expect(applied, isEmpty);
    });

    test('응답에 토큰이 없으면 세션 적용 없이 실패한다', () async {
      final service = serviceReturning(200, {'authUserId': 'x'});

      await expectLater(service.redeemQrToken('t'), throwsA(isA<ApiError>()));
      expect(applied, isEmpty);
    });
  });
}
