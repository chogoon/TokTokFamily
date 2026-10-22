import 'dart:async';
import 'dart:convert';

import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/services/api_client.dart';
import 'package:family_toktok/services/qr_auth_service.dart';
import 'package:family_toktok/state/auth_controller.dart';
import 'package:family_toktok/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

const kidMember = Member(
  id: 'k1',
  familyId: 'f1',
  role: MemberRole.kid,
  name: '하린',
);

class FakeKidAuthBackend implements AuthBackend {
  bool signedIn = false;
  final _changes = StreamController<bool>.broadcast();

  void emit(bool value) {
    signedIn = value;
    _changes.add(value);
  }

  @override
  bool get hasSession => signedIn;

  @override
  Stream<bool> get sessionChanges => _changes.stream;

  @override
  Future<Member?> fetchCurrentMember() async => signedIn ? kidMember : null;

  @override
  Future<String?> fetchFamilyName(String familyId) async => '우리집';

  @override
  Future<void> signOut() async => emit(false);
}

/// 아이 로그인 화면 테스트용 앱. backend 응답(상태코드/본문)과 세션 적용을 가짜로 만든다.
class KidLoginHarness {
  KidLoginHarness({this.status = 200, Object? body})
      : body = body ??
            const {
              'accessToken': 'access-abc',
              'refreshToken': 'refresh-xyz',
              'authUserId': 'kid-auth',
            };

  int status;
  Object body;
  final requests = <http.Request>[];
  final appliedSessions = <String>[];
  final backend = FakeKidAuthBackend();
  late final AuthController auth;

  Future<Widget> build(Widget screen) async {
    final api = ApiClient(
      baseUrl: 'http://localhost:4000',
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response(jsonEncode(body), status,
            headers: {'content-type': 'application/json'});
      }),
      accessTokenProvider: () async => null,
    );
    final service = QrAuthService(api, applySession: (access, refresh) async {
      appliedSessions.add(access);
      backend.emit(true);
    });
    auth = AuthController(backend);
    await auth.initialize();

    return MultiProvider(
      providers: [
        Provider<QrAuthService>.value(value: service),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: Text('ROOT')),
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => screen),
        initialRoute: '/kid',
      ),
    );
  }

  Map<String, dynamic> get lastBody =>
      jsonDecode(requests.last.body) as Map<String, dynamic>;
}
