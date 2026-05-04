// Plan SC: FR-65 — RecurringRule.isDue 순수 함수 단위 테스트 5건.
// Plan SC: FR-70 — weekly/daily isDue 4건 추가 (M5).

import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/features/dashboard/data/recurring_rule_repository.dart';

RecurringRule _make({
  required int dayOfMonth,
  bool isActive = true,
  DateTime? lastConfirmedAt,
  String recurrenceType = 'monthly',
  int? dayOfWeek,
}) => RecurringRule(
      id: 1,
      templateId: 1,
      dayOfMonth: dayOfMonth,
      isActive: isActive,
      lastConfirmedAt: lastConfirmedAt,
      templateName: 'test',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      recurrenceType: recurrenceType,
      dayOfWeek: dayOfWeek,
    );

void main() {
  group('RecurringRule.isDue', () {
    final today = DateTime(2026, 4, 20); // 2026-04-20

    test('isActive=false → always false', () {
      final rule = _make(dayOfMonth: 15, isActive: false);
      expect(rule.isDue(today), isFalse);
    });

    test('dayOfMonth 15, today 10 → not yet due', () {
      final rule = _make(dayOfMonth: 15);
      final earlyToday = DateTime(2026, 4, 10);
      expect(rule.isDue(earlyToday), isFalse);
    });

    test('dayOfMonth 15, today 20, lastConfirmedAt=null → due', () {
      final rule = _make(dayOfMonth: 15, lastConfirmedAt: null);
      expect(rule.isDue(today), isTrue);
    });

    test('dayOfMonth 15, today 20, lastConfirmedAt=이번달 16일 → already handled', () {
      final rule = _make(
        dayOfMonth: 15,
        lastConfirmedAt: DateTime(2026, 4, 16),
      );
      expect(rule.isDue(today), isFalse);
    });

    test('dayOfMonth 15, today 20, lastConfirmedAt=전월 15일 → due (new month)', () {
      final rule = _make(
        dayOfMonth: 15,
        lastConfirmedAt: DateTime(2026, 3, 15),
      );
      expect(rule.isDue(today), isTrue);
    });
  });

  group('RecurringRule.isDue — weekly', () {
    // 2026-04-20 = 월요일 (weekday=1)
    final monday = DateTime(2026, 4, 20);
    // 2026-04-21 = 화요일 (weekday=2)
    final tuesday = DateTime(2026, 4, 21);

    test('weekly 월요일, today=월요일, lastConfirmedAt=null → due', () {
      final rule = _make(
        dayOfMonth: 1,
        recurrenceType: 'weekly',
        dayOfWeek: 1,
        lastConfirmedAt: null,
      );
      expect(rule.isDue(monday), isTrue);
    });

    test('weekly 월요일, today=화요일 → not due (요일 불일치)', () {
      final rule = _make(
        dayOfMonth: 1,
        recurrenceType: 'weekly',
        dayOfWeek: 1,
        lastConfirmedAt: null,
      );
      expect(rule.isDue(tuesday), isFalse);
    });
  });

  group('RecurringRule.isDue — daily', () {
    final today = DateTime(2026, 4, 20);

    test('daily, lastConfirmedAt=null → due', () {
      final rule = _make(
        dayOfMonth: 1,
        recurrenceType: 'daily',
        lastConfirmedAt: null,
      );
      expect(rule.isDue(today), isTrue);
    });

    test('daily, lastConfirmedAt=today → already handled', () {
      final rule = _make(
        dayOfMonth: 1,
        recurrenceType: 'daily',
        lastConfirmedAt: DateTime(2026, 4, 20, 8, 0),
      );
      expect(rule.isDue(today), isFalse);
    });
  });
}
