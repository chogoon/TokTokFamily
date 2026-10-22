import '../services/api_client.dart';

// backend REST 에러(status + error 문구)를 화면용 한국어 문구로 바꾸는 순수 함수.
// 상태코드 의미는 backend/src/routes/families.ts 참조.

const _alreadyMember = '이미 다른 가족에 참여하고 있어요';
const _sessionExpired = '로그인이 만료됐어요. 다시 로그인해주세요';

String createFamilyErrorMessage(Object error) {
  if (error is! ApiError) return '가족을 만들지 못했어요';
  switch (error.status) {
    case 401:
      return _sessionExpired;
    case 409:
      return _alreadyMember;
    case 400:
      return '입력한 내용을 다시 확인해주세요';
    default:
      return '가족을 만들지 못했어요';
  }
}

String redeemInviteErrorMessage(Object error) {
  if (error is! ApiError) return '가족에 참여하지 못했어요';
  switch (error.status) {
    case 401:
      return _sessionExpired;
    case 404:
      return '초대 코드를 찾을 수 없어요';
    case 409:
      // 409는 "이미 사용된 코드"와 "이미 다른 가족 소속" 두 경우가 있다.
      return error.message.contains('already a member')
          ? _alreadyMember
          : '이미 사용된 초대 코드예요';
    case 410:
      return '초대 코드가 만료됐어요';
    case 400:
      return '입력한 내용을 다시 확인해주세요';
    default:
      return '가족에 참여하지 못했어요';
  }
}

String createInviteErrorMessage(Object error) {
  if (error is! ApiError) return '초대 코드를 만들지 못했어요';
  switch (error.status) {
    case 401:
      return _sessionExpired;
    case 403:
      return '보호자만 초대 코드를 만들 수 있어요';
    default:
      return '초대 코드를 만들지 못했어요';
  }
}

String addKidErrorMessage(Object error) {
  if (error is! ApiError) return '아이를 추가하지 못했어요';
  switch (error.status) {
    case 401:
      return _sessionExpired;
    case 403:
      return '보호자만 아이를 추가할 수 있어요';
    case 400:
      return '이름(8자 이하)과 캐릭터를 다시 확인해주세요';
    default:
      return '아이를 추가하지 못했어요';
  }
}

String issueQrErrorMessage(Object error) {
  if (error is! ApiError) return 'QR 코드를 만들지 못했어요';
  switch (error.status) {
    case 401:
      return _sessionExpired;
    case 403:
      return '보호자만 QR 코드를 만들 수 있어요';
    case 404:
      return '우리 가족 아이를 찾을 수 없어요';
    default:
      return 'QR 코드를 만들지 못했어요';
  }
}
