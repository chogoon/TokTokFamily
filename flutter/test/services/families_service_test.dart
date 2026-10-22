import 'dart:convert';

import 'package:family_toktok/services/api_client.dart';
import 'package:family_toktok/services/families_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late List<http.Request> requests;

  ApiClient clientReturning(int status, Object body, {String? token = 'jwt-123'}) {
    requests = [];
    final mock = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json'});
    });
    return ApiClient(
      baseUrl: 'http://localhost:4000',
      httpClient: mock,
      accessTokenProvider: () async => token,
    );
  }

  group('FamiliesService.createFamily', () {
    test('POST /families에 JSON 바디 + Bearer 토큰을 보내고 결과를 파싱한다', () async {
      final service = FamiliesService(
          clientReturning(201, {'familyId': 'f1', 'memberId': 'm1'}));

      final result = await service.createFamily(
          familyName: '우리가족', parentName: '엄마');

      expect(result.familyId, 'f1');
      expect(result.memberId, 'm1');

      final req = requests.single;
      expect(req.method, 'POST');
      expect(req.url.toString(), 'http://localhost:4000/families');
      expect(req.headers['Authorization'], 'Bearer jwt-123');
      expect(req.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(req.body), {'familyName': '우리가족', 'parentName': '엄마'});
    });

    test('입력값 앞뒤 공백을 제거해서 보낸다', () async {
      final service = FamiliesService(
          clientReturning(201, {'familyId': 'f1', 'memberId': 'm1'}));

      await service.createFamily(familyName: ' 우리가족 ', parentName: ' 엄마 ');

      expect(jsonDecode(requests.single.body),
          {'familyName': '우리가족', 'parentName': '엄마'});
    });

    test('실패 응답이면 status와 backend error 문구를 담은 ApiError를 던진다', () async {
      final service = FamiliesService(
          clientReturning(409, {'error': 'already a member of a family'}));

      expect(
        () => service.createFamily(familyName: 'a', parentName: 'b'),
        throwsA(isA<ApiError>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.message, 'message', 'already a member of a family')),
      );
    });

    test('세션이 없으면 Authorization 헤더 없이 보낸다 (backend가 401로 거절)', () async {
      final service = FamiliesService(clientReturning(
          401, {'error': 'missing bearer token'},
          token: null));

      await expectLater(
        service.createFamily(familyName: 'a', parentName: 'b'),
        throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)),
      );
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('FamiliesService.redeemInvite', () {
    test('POST /families/invites/redeem에 정규화된 코드와 이름을 보낸다', () async {
      final service = FamiliesService(
          clientReturning(200, {'familyId': 'f2', 'memberId': 'm2'}));

      final result =
          await service.redeemInvite(code: ' abcd efgh ', parentName: ' 아빠 ');

      expect(result.familyId, 'f2');
      expect(result.memberId, 'm2');
      final req = requests.single;
      expect(req.url.path, '/families/invites/redeem');
      expect(jsonDecode(req.body), {'code': 'ABCDEFGH', 'parentName': '아빠'});
    });

    test('JSON이 아닌 에러 응답도 상태코드 기반 ApiError로 변환한다', () async {
      requests = [];
      final client = ApiClient(
        baseUrl: 'http://localhost:4000/',
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response('Bad Gateway', 502);
        }),
        accessTokenProvider: () async => 't',
      );

      await expectLater(
        FamiliesService(client).redeemInvite(code: 'ABCDEFGH', parentName: 'a'),
        throwsA(isA<ApiError>()
            .having((e) => e.status, 'status', 502)
            .having((e) => e.message, 'message', 'request failed (502)')),
      );
      // baseUrl 끝의 슬래시가 중복되지 않아야 한다
      expect(requests.single.url.toString(),
          'http://localhost:4000/families/invites/redeem');
    });
  });
}
