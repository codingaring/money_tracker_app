// Plan SC: FR-65 — RecurringRuleRepository 통합 테스트 3건.
// In-memory Drift: insert / markHandled / isActive=false 동작 검증.

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/db/app_database.dart';
import 'package:money_tracker_app/features/dashboard/data/recurring_rule_repository.dart';
import 'package:money_tracker_app/features/transactions/domain/transaction.dart';

Future<int> _insertTemplate(AppDatabase db, String name) =>
    db.into(db.txTemplates).insert(
          TxTemplatesCompanion.insert(name: name, type: TxType.expense),
        );

void main() {
  late AppDatabase db;
  late RecurringRuleRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = RecurringRuleRepository(db);
  });

  tearDown(() async => db.close());

  test('insert rule → watchAll returns 1 rule, isDue(today)=true', () async {
    final today = DateTime.now();
    final templateId = await _insertTemplate(db, '월세');
    await repo.insert(RecurringRulesCompanion.insert(
      templateId: templateId,
      dayOfMonth: today.day,
    ));

    final rules = await repo.watchAll().first;
    expect(rules, hasLength(1));
    expect(rules[0].isDue(today), isTrue);
  });

  test('markHandled → isDue(today)=false', () async {
    final today = DateTime.now();
    final templateId = await _insertTemplate(db, '통신비');
    final id = await repo.insert(RecurringRulesCompanion.insert(
      templateId: templateId,
      dayOfMonth: today.day,
    ));

    await repo.markHandled(id);

    final rules = await repo.watchAll().first;
    expect(rules[0].isDue(today), isFalse);
  });

  test('isActive=false → isDue(today)=false', () async {
    final today = DateTime.now();
    final templateId = await _insertTemplate(db, '구독료');
    await repo.insert(RecurringRulesCompanion.insert(
      templateId: templateId,
      dayOfMonth: today.day,
      isActive: const Value(false),
    ));

    final rules = await repo.watchAll().first;
    expect(rules[0].isDue(today), isFalse);
  });
}
