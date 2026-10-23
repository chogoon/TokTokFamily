import 'dart:async';

import 'package:family_toktok/models/member.dart';
import 'package:family_toktok/state/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthBackend implements AuthBackend {
  FakeAuthBackend({this.signedIn = false, this.member, this.familyName});

  bool signedIn;
  Member? member;
  String? familyName;
  int memberFetches = 0;
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
  Future<Member?> fetchCurrentMember() async {
    memberFetches++;
    return member;
  }

  @override
  Future<String?> fetchFamilyName(String familyId) async => familyName;

  @override
  Future<void> signOut() async => emit(false);
}

const _parent = Member(
  id: 'm1',
  familyId: 'f1',
  role: MemberRole.parent,
  name: '엄마',
);

void main() {
  test('세션이 없으면 로딩이 끝난 뒤 signedOut 상태', () async {
    final controller = AuthController(FakeAuthBackend());
    expect(controller.status, AuthStatus.loading);

    await controller.initialize();

    expect(controller.status, AuthStatus.signedOut);
    expect(controller.member, isNull);
  });

  test('세션은 있지만 가족이 없으면 needsFamily', () async {
    final controller = AuthController(FakeAuthBackend(signedIn: true));
    await controller.initialize();

    expect(controller.status, AuthStatus.needsFamily);
  });

  test('세션+멤버가 있으면 ready 상태이고 member/family 이름을 제공한다', () async {
    final controller = AuthController(
        FakeAuthBackend(signedIn: true, member: _parent, familyName: '우리가족'));
    await controller.initialize();

    expect(controller.status, AuthStatus.ready);
    expect(controller.member?.name, '엄마');
    expect(controller.member?.role, MemberRole.parent);
    expect(controller.familyName, '우리가족');
  });

  test('가족 생성 후 refreshMember를 부르면 needsFamily → ready로 바뀐다', () async {
    final backend = FakeAuthBackend(signedIn: true);
    final controller = AuthController(backend);
    await controller.initialize();
    expect(controller.status, AuthStatus.needsFamily);

    backend
      ..member = _parent
      ..familyName = '우리가족';
    var notified = 0;
    controller.addListener(() => notified++);
    await controller.refreshMember();

    expect(controller.status, AuthStatus.ready);
    expect(notified, greaterThan(0));
  });

  test('로그아웃 이벤트가 오면 member를 비우고 signedOut', () async {
    final backend =
        FakeAuthBackend(signedIn: true, member: _parent, familyName: '우리가족');
    final controller = AuthController(backend);
    await controller.initialize();

    await controller.signOut();
    await Future<void>.delayed(Duration.zero);

    expect(controller.status, AuthStatus.signedOut);
    expect(controller.member, isNull);
    expect(controller.familyName, isNull);
  });

  test('로그인 이벤트가 오면 멤버를 다시 조회한다', () async {
    final backend = FakeAuthBackend();
    final controller = AuthController(backend);
    await controller.initialize();

    backend.member = _parent;
    backend.emit(true);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(backend.memberFetches, 1);
    expect(controller.status, AuthStatus.ready);
  });

  group('onMemberReady (푸시 토큰 등록 연결 지점)', () {
    test('구성원 조회에 성공하면 그 member로 한 번 호출된다', () async {
      final calls = <Member>[];
      final controller = AuthController(
        FakeAuthBackend(signedIn: true, member: _parent, familyName: '우리가족'),
        onMemberReady: (m) async => calls.add(m),
      );
      await controller.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(calls.map((m) => m.id), ['m1']);
    });

    test('가족이 없으면(member null) 호출되지 않는다', () async {
      var calls = 0;
      final controller = AuthController(
        FakeAuthBackend(signedIn: true),
        onMemberReady: (_) async => calls++,
      );
      await controller.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(calls, 0);
    });

    test('콜백이 비동기로 throw해도 로그인은 ready로 끝난다 (soft-fail)', () async {
      final controller = AuthController(
        FakeAuthBackend(signedIn: true, member: _parent, familyName: '우리가족'),
        onMemberReady: (_) async => throw Exception('push failed'),
      );
      await controller.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(controller.status, AuthStatus.ready);
      expect(controller.lastError, isNull);
    });

    test('콜백이 동기로 throw해도 로그인은 ready로 끝난다 (soft-fail)', () async {
      final controller = AuthController(
        FakeAuthBackend(signedIn: true, member: _parent, familyName: '우리가족'),
        onMemberReady: (_) => throw StateError('sync boom'),
      );
      await controller.initialize();

      expect(controller.status, AuthStatus.ready);
      expect(controller.member?.id, 'm1');
    });

    test('콜백이 끝나지 않아도(권한 다이얼로그 대기 등) 로그인 완료를 막지 않는다', () async {
      final never = Completer<void>();
      final controller = AuthController(
        FakeAuthBackend(signedIn: true, member: _parent, familyName: '우리가족'),
        onMemberReady: (_) => never.future,
      );
      await controller.initialize();

      expect(controller.status, AuthStatus.ready);
    });
  });
}
