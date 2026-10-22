import 'package:family_toktok/utils/api_error_messages.dart';
import 'package:family_toktok/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('createFamilyErrorMessage', () {
    test('409는 이미 가족에 속해 있다는 안내', () {
      expect(
        createFamilyErrorMessage(const ApiError(409, 'already a member of a family')),
        '이미 다른 가족에 참여하고 있어요',
      );
    });

    test('401은 다시 로그인 안내', () {
      expect(
        createFamilyErrorMessage(const ApiError(401, 'invalid token')),
        '로그인이 만료됐어요. 다시 로그인해주세요',
      );
    });

    test('ApiError가 아니면 일반 실패 문구', () {
      expect(createFamilyErrorMessage(Exception('network')), '가족을 만들지 못했어요');
    });
  });

  group('redeemInviteErrorMessage', () {
    test('backend /families/invites/redeem 상태코드별 문구', () {
      expect(redeemInviteErrorMessage(const ApiError(404, 'invite not found')),
          '초대 코드를 찾을 수 없어요');
      expect(redeemInviteErrorMessage(const ApiError(409, 'invite already used')),
          '이미 사용된 초대 코드예요');
      expect(
          redeemInviteErrorMessage(
              const ApiError(409, 'already a member of a family')),
          '이미 다른 가족에 참여하고 있어요');
      expect(redeemInviteErrorMessage(const ApiError(410, 'invite expired')),
          '초대 코드가 만료됐어요');
    });

    test('ApiError가 아니면 일반 실패 문구', () {
      expect(redeemInviteErrorMessage(Exception('x')), '가족에 참여하지 못했어요');
    });
  });
}
