import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/member.dart';

/// AuthController가 의존하는 인증/구성원 조회 경계. 테스트에서 fake로 대체한다.
abstract class AuthBackend {
  bool get hasSession;

  /// 세션 유무 변화 (로그인 = true, 로그아웃 = false).
  Stream<bool> get sessionChanges;

  Future<Member?> fetchCurrentMember();
  Future<String?> fetchFamilyName(String familyId);
  Future<void> signOut();
}

enum AuthStatus {
  /// 저장된 세션 확인 중
  loading,

  /// Supabase 세션 없음 → 시작 화면
  signedOut,

  /// 세션은 있지만 members 행이 없음 → 가족 만들기/초대 코드 참여
  needsFamily,

  /// 가족 구성원으로 로그인 완료
  ready,
}

/// 로그인한 구성원(role, family_id)을 앱 전역에 제공한다. RN `contexts/AuthContext.tsx`에 대응.
class AuthController extends ChangeNotifier {
  AuthController(this._backend, {this.onMemberReady});

  final AuthBackend _backend;

  /// 구성원 조회 성공(로그인 완료) 시 호출된다 — 푸시 토큰 등록 연결 지점.
  /// RN `AuthContext.refreshMember` 안의 registerForPushNotificationsAsync 호출에 대응.
  /// 권한 다이얼로그 대기 등으로 오래 걸릴 수 있어 기다리지 않고, 실패도 삼킨다(soft-fail).
  final Future<void> Function(Member member)? onMemberReady;
  StreamSubscription<bool>? _subscription;

  AuthStatus _status = AuthStatus.loading;
  bool _hasSession = false;
  Member? _member;
  String? _familyName;
  Object? _lastError;

  AuthStatus get status => _status;
  Member? get member => _member;
  String? get familyName => _familyName;

  /// 구성원 조회 실패 원인 (네트워크 등). 화면에서 재시도 안내용.
  Object? get lastError => _lastError;

  Future<void> initialize() async {
    _hasSession = _backend.hasSession;
    _subscription = _backend.sessionChanges.listen(_onSessionChanged);

    if (_hasSession) {
      await refreshMember();
    } else {
      _setSignedOut();
    }
  }

  /// 가족 생성/초대 참여 직후 호출해 members 행을 다시 읽는다.
  Future<void> refreshMember() async {
    try {
      final member = await _backend.fetchCurrentMember();
      _member = member;
      _familyName = member == null
          ? null
          : await _backend.fetchFamilyName(member.familyId);
      _lastError = null;
      _status = member == null ? AuthStatus.needsFamily : AuthStatus.ready;
      if (member != null) _notifyMemberReady(member);
    } catch (e) {
      _lastError = e;
      _member = null;
      _familyName = null;
      _status = AuthStatus.needsFamily;
    }
    notifyListeners();
  }

  Future<void> signOut() => _backend.signOut();

  void _notifyMemberReady(Member member) {
    final callback = onMemberReady;
    if (callback == null) return;
    try {
      unawaited(callback(member).catchError((Object e) {
        debugPrint('[auth] onMemberReady 실패(무시): $e');
      }));
    } catch (e) {
      debugPrint('[auth] onMemberReady 실패(무시): $e');
    }
  }

  // 토큰 갱신(tokenRefreshed)/initialSession 이벤트마다 members를 다시 읽지 않도록
  // 세션 유무가 실제로 바뀐 경우에만 반응한다.
  void _onSessionChanged(bool hasSession) {
    if (hasSession == _hasSession) return;
    _hasSession = hasSession;
    if (hasSession) {
      refreshMember();
    } else {
      _setSignedOut();
    }
  }

  void _setSignedOut() {
    _member = null;
    _familyName = null;
    _lastError = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
