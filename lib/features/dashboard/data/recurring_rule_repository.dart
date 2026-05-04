// Design Ref: §4.1 — RecurringRule domain + repo (Option A minimal).
// isDue 순수 함수: sideeffect 없는 날짜 비교. 단위 테스트 대상.
// v6: recurrenceType(monthly/weekly/daily) + dayOfWeek 추가.
// markHandled: confirm + skip 동일 함수 (last_confirmed_at 갱신).

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';

// ── Domain ─────────────────────────────────────────────────────────────────

class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.templateId,
    required this.dayOfMonth,
    required this.isActive,
    required this.lastConfirmedAt,
    required this.templateName,
    required this.createdAt,
    required this.updatedAt,
    this.templateAmount,
    this.recurrenceType = 'monthly',
    this.dayOfWeek,
  });

  final int id;
  final int templateId;
  final int dayOfMonth;
  final bool isActive;
  final DateTime? lastConfirmedAt;
  final String templateName;

  /// nullable — NULL이면 사용 시 사용자가 입력.
  final int? templateAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// v6: 'monthly' | 'weekly' | 'daily'. DEFAULT 'monthly'.
  final String recurrenceType;

  /// v6: 주간 반복 요일 (1=월~7=일). NULL = monthly/daily.
  final int? dayOfWeek;

  /// Plan SC-1: isDue 순수 함수 — 단위 테스트 필수.
  bool isDue(DateTime today) {
    if (!isActive) return false;
    switch (recurrenceType) {
      case 'daily':
        if (lastConfirmedAt == null) return true;
        final lc = lastConfirmedAt!;
        return lc.year < today.year ||
            lc.month < today.month ||
            lc.day < today.day;
      case 'weekly':
        final dow = dayOfWeek ?? 1;
        if (today.weekday != dow) return false;
        if (lastConfirmedAt == null) return true;
        // 이번 주 월요일 기준으로 이미 처리했는지 확인
        final todayMon =
            today.subtract(Duration(days: today.weekday - 1));
        final lcDate = lastConfirmedAt!;
        final lcMon =
            lcDate.subtract(Duration(days: lcDate.weekday - 1));
        return lcMon.isBefore(todayMon);
      default: // monthly
        if (dayOfMonth > today.day) return false;
        if (lastConfirmedAt == null) return true;
        final lc = lastConfirmedAt!;
        return lc.year < today.year ||
            (lc.year == today.year && lc.month < today.month);
    }
  }
}

// ── Repository ─────────────────────────────────────────────────────────────

class RecurringRuleRepository {
  RecurringRuleRepository(this._db);

  final AppDatabase _db;

  /// 활성 여부 불문 전체 규칙 + 템플릿 이름/금액 JOIN. dayOfMonth asc 정렬.
  Stream<List<RecurringRule>> watchAll() {
    final query = _db.select(_db.recurringRules).join([
      innerJoin(
        _db.txTemplates,
        _db.txTemplates.id.equalsExp(_db.recurringRules.templateId),
      ),
    ])
      ..orderBy([OrderingTerm.asc(_db.recurringRules.dayOfMonth)]);

    return query.watch().map(
          (rows) => rows.map((row) {
            final r = row.readTable(_db.recurringRules);
            final t = row.readTable(_db.txTemplates);
            return RecurringRule(
              id: r.id,
              templateId: r.templateId,
              dayOfMonth: r.dayOfMonth,
              isActive: r.isActive,
              lastConfirmedAt: r.lastConfirmedAt,
              templateName: t.name,
              templateAmount: t.amount,
              createdAt: r.createdAt,
              updatedAt: r.updatedAt,
              recurrenceType: r.recurrenceType,
              dayOfWeek: r.dayOfWeek,
            );
          }).toList(),
        );
  }

  Future<int> insert(RecurringRulesCompanion c) =>
      _db.into(_db.recurringRules).insert(c);

  Future<void> update(int id, RecurringRulesCompanion c) =>
      (_db.update(_db.recurringRules)..where((r) => r.id.equals(id))).write(c);

  Future<void> delete(int id) =>
      (_db.delete(_db.recurringRules)..where((r) => r.id.equals(id))).go();

  /// confirm or skip — lastConfirmedAt을 now로 갱신.
  /// 두 액션 결과 동일: 이번달 isDue = false.
  Future<void> markHandled(int id) =>
      (_db.update(_db.recurringRules)..where((r) => r.id.equals(id))).write(
        RecurringRulesCompanion(lastConfirmedAt: Value(DateTime.now())),
      );
}
