import 'package:family_toktok/utils/qr_countdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('remainingSeconds', () {
    test('만료 시각까지 남은 초를 반환한다', () {
      final now = DateTime.utc(2026, 10, 22, 12, 0, 0);
      final expiresAt = DateTime.utc(2026, 10, 22, 12, 1, 30);
      expect(remainingSeconds(expiresAt, now), 90);
    });

    test('1초 미만으로 남았으면 올림해서 1초로 본다 (0 표시 전에 만료 처리 금지)', () {
      final now = DateTime.utc(2026, 10, 22, 12, 0, 0);
      final expiresAt = now.add(const Duration(milliseconds: 200));
      expect(remainingSeconds(expiresAt, now), 1);
    });

    test('이미 만료됐으면 0을 반환한다 (음수 금지)', () {
      final now = DateTime.utc(2026, 10, 22, 12, 5, 0);
      final expiresAt = DateTime.utc(2026, 10, 22, 12, 0, 0);
      expect(remainingSeconds(expiresAt, now), 0);
    });

    test('정확히 만료 시각이면 0', () {
      final t = DateTime.utc(2026, 10, 22, 12, 0, 0);
      expect(remainingSeconds(t, t), 0);
    });

    test('타임존이 다른 DateTime끼리도 절대 시각 기준으로 계산한다', () {
      final expiresAt = DateTime.parse('2026-10-22T03:02:00.000Z');
      final now = DateTime.parse('2026-10-22T12:00:00+09:00');
      expect(remainingSeconds(expiresAt, now), 120);
    });
  });

  group('formatCountdown', () {
    test('90초를 01:30으로 표시한다 (mm:ss)', () {
      expect(formatCountdown(90), '01:30');
    });

    test('5초를 00:05로 표시한다', () {
      expect(formatCountdown(5), '00:05');
    });

    test('0초를 00:00으로 표시한다', () {
      expect(formatCountdown(0), '00:00');
    });

    test('120초(정확히 2분)를 02:00으로 표시한다', () {
      expect(formatCountdown(120), '02:00');
    });

    test('음수가 들어와도 00:00으로 clamp한다', () {
      expect(formatCountdown(-3), '00:00');
    });
  });
}
