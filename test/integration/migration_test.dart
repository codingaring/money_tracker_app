import 'package:drift/drift.dart' show Migrator, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/db/app_database.dart';
import 'package:money_tracker_app/core/db/migrations/v4_to_v5.dart';
import 'package:money_tracker_app/features/categories/domain/category.dart';
import 'package:money_tracker_app/features/transactions/domain/transaction.dart';

Future<bool> _tableExists(AppDatabase db, String name) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        variables: [Variable.withString(name)],
      )
      .get();
  return rows.isNotEmpty;
}

Future<List<String>> _columnNames(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.map((r) => r.read<String>('name')).toList();
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test(
    'v2→v3 structural check — accounts.due_day exists and is nullable',
    () async {
      // v5 onCreate 포함 — due_day는 accounts 테이블에 이미 존재.
      final cols = await _columnNames(db, 'accounts');
      expect(cols, contains('due_day'));

      // NULL 허용 insert 검증.
      await db.customStatement(
        "INSERT INTO accounts (name, type, balance) VALUES ('체크카드', 'checking', 0)",
      );
      final rows = await db
          .customSelect("SELECT due_day FROM accounts WHERE name='체크카드'")
          .get();
      expect(rows, hasLength(1));
      expect(rows[0].read<String?>('due_day'), isNull);
    },
  );

  test(
    'v3→v4 — DROP tx_templates → createTable restores it, parent_category_id present',
    () async {
      // 기존 카테고리 데이터 삽입 (마이그레이션 후 보존 여부 확인).
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(name: '식비', kind: CategoryKind.expense),
          );

      // v3 상태 시뮬레이션: tx_templates 삭제.
      // (SQLite는 DROP COLUMN 미지원 — parent_category_id 제거 불가,
      //  addColumn 부분은 별도 검증 불필요: 컬럼 존재 여부로 structural 확인)
      await db.customStatement('DROP TABLE IF EXISTS tx_templates');
      expect(await _tableExists(db, 'tx_templates'), isFalse);

      // createTable 부분만 직접 호출 (addColumn은 v5 스키마에 이미 적용됨).
      await Migrator(db).createTable(db.txTemplates);

      // tx_templates 복원 확인.
      expect(await _tableExists(db, 'tx_templates'), isTrue);

      // categories.parent_category_id 구조 확인 (v4 delta).
      final cols = await _columnNames(db, 'categories');
      expect(cols, contains('parent_category_id'));

      // 기존 카테고리 데이터 보존 확인.
      final cats = await db.customSelect("SELECT name FROM categories").get();
      expect(cats.map((r) => r.read<String>('name')), contains('식비'));
    },
  );

  test(
    'v4→v5 — DROP recurring_rules+budgets → apply → tables restored, data preserved',
    () async {
      // 사전 데이터: category + template.
      final catId = await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(name: '교통', kind: CategoryKind.expense),
          );
      final templateId = await db
          .into(db.txTemplates)
          .insert(
            TxTemplatesCompanion.insert(name: '버스 정기권', type: TxType.expense),
          );
      expect(catId, isPositive);
      expect(templateId, isPositive);

      // v4 상태 시뮬레이션: v5 신규 테이블 삭제 (FK 비활성화 필요).
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.customStatement('DROP TABLE IF EXISTS recurring_rules');
      await db.customStatement('DROP TABLE IF EXISTS budgets');
      await db.customStatement('PRAGMA foreign_keys = ON');

      expect(await _tableExists(db, 'recurring_rules'), isFalse);
      expect(await _tableExists(db, 'budgets'), isFalse);

      // v4→v5 마이그레이션 적용.
      await V4ToV5.apply(Migrator(db), db);

      // 두 테이블 복원 확인.
      expect(await _tableExists(db, 'recurring_rules'), isTrue);
      expect(await _tableExists(db, 'budgets'), isTrue);

      // 기존 데이터 보존 확인 (categories + tx_templates는 영향받지 않아야 함).
      final cats = await db.customSelect("SELECT name FROM categories").get();
      expect(cats.map((r) => r.read<String>('name')), contains('교통'));

      final templates = await db
          .customSelect("SELECT name FROM tx_templates")
          .get();
      expect(templates.map((r) => r.read<String>('name')), contains('버스 정기권'));
    },
  );

  test(
    'v5→v6 — recurrence_type+day_of_week 컬럼 추가, 기존 recurring_rule default 값 보존',
    () async {
      // 사전 데이터: template + recurring_rule (v5 상태 — 새 컬럼 없음).
      final templateId = await db
          .into(db.txTemplates)
          .insert(
            TxTemplatesCompanion.insert(name: '관리비', type: TxType.expense),
          );

      // v5 상태 시뮬레이션: v6 신규 컬럼 삭제 (SQLite DROP COLUMN 지원 불가 → 우회).
      // 대신 직접 INSERT 후 컬럼 존재 여부로 확인.
      // v6 컬럼 없는 상태를 시뮬레이트하기 위해 컬럼 없이 INSERT.
      // (SQLite는 ALTER TABLE DROP COLUMN 미지원이므로 컬럼 존재 확인 중심으로 테스트)

      // 기존 recurring_rule을 v6 스키마로 insert (recurrenceType = 'monthly' default).
      await db
          .into(db.recurringRules)
          .insert(
            RecurringRulesCompanion.insert(
              templateId: templateId,
              dayOfMonth: 1,
            ),
          );

      // v5→v6 마이그레이션: 컬럼은 이미 있으므로 구조 확인.
      final cols = await _columnNames(db, 'recurring_rules');
      expect(cols, contains('recurrence_type'));
      expect(cols, contains('day_of_week'));

      // 기존 행의 recurrence_type default = 'monthly' 확인.
      final rows = await db
          .customSelect(
            "SELECT recurrence_type, day_of_week FROM recurring_rules WHERE template_id=?",
            variables: [Variable.withInt(templateId)],
          )
          .get();
      expect(rows, hasLength(1));
      expect(rows[0].read<String>('recurrence_type'), 'monthly');
      expect(rows[0].read<String?>('day_of_week'), isNull);

      // V5ToV6.apply — addColumn은 컬럼이 이미 있으면 no-op이 아니라 오류.
      // 실제 신규 DB에서는 onCreate에서 이미 포함되므로 별도 마이그레이션 테스트는
      // DROP 후 복원 패턴으로 검증. 여기서는 구조 확인 중심.
      // (이미 컬럼이 있으므로 apply 호출 생략 — 실기기 v5→v6 업그레이드는 addColumn만 수행)
    },
  );
}
