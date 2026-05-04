// Design Ref: §3 — Schema v4 (M3 delta: tx_templates 신규 + categories.parent_category_id).
// accounts (+due_day v3), categories (+is_fixed M1, +parent_category_id v4),
// transactions (+from/to/deltas + 4-type), sync_queue, kv_store, tx_templates (v4).

import 'package:drift/drift.dart';

import '../../features/accounts/domain/account.dart';
import '../../features/categories/domain/category.dart';
import '../../features/sync/domain/sync_op.dart';
import '../../features/transactions/domain/transaction.dart';

@DataClassName('Account')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get type => textEnum<AccountType>()();

  /// KRW. Negative for liabilities (credit_card, loan).
  IntColumn get balance => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Self-FK for parent (e.g., card → bank). M2 트리 UI에서 사용.
  IntColumn get parentAccountId => integer()
      .nullable()
      .customConstraint('NULL REFERENCES accounts(id)')();

  TextColumn get note => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// v3: 신용카드 결제일 (1-31). credit_card 타입에만 의미.
  /// UI에서 type 분기로 NULL 강제. 단축월(2월) 안전을 위해 도메인 레이어에서 28로 clamp.
  IntColumn get dueDay => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get kind => textEnum<CategoryKind>()();

  /// 고정비(true) vs 변동비(false). expense 카테고리에만 의미.
  BoolColumn get isFixed => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// v4: 2-level hierarchy. NULL = 대분류, 값 있음 = 소분류.
  /// ON DELETE SET NULL — 대분류 삭제 시 자식이 대분류로 승격 (cascade는
  /// 거래 데이터 손실 위험).
  IntColumn get parentCategoryId => integer()
      .nullable()
      .customConstraint(
          'NULL REFERENCES categories(id) ON DELETE SET NULL')();
}

@DataClassName('TxRow')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// UUID v4 — Sheets row 매칭 키 (tx_id 컬럼).
  TextColumn get localId => text().unique()();

  TextColumn get type => textEnum<TxType>()();

  /// Always > 0. Sign is determined by from_delta/to_delta.
  IntColumn get amount => integer()();

  /// expense/income only. NULL for transfer/valuation.
  IntColumn get categoryId => integer()
      .nullable()
      .customConstraint('NULL REFERENCES categories(id)')();

  /// expense, transfer. NULL for income, valuation.
  IntColumn get fromAccountId => integer()
      .nullable()
      .customConstraint('NULL REFERENCES accounts(id)')();

  /// income, transfer, valuation. NULL for expense.
  IntColumn get toAccountId => integer()
      .nullable()
      .customConstraint('NULL REFERENCES accounts(id)')();

  /// What this tx applied to from_account.balance (signed). NULL = no change.
  /// Stored to make undo on update/delete trivial.
  IntColumn get fromDelta => integer().nullable()();

  /// What this tx applied to to_account.balance (signed). NULL = no change.
  IntColumn get toDelta => integer().nullable()();

  TextColumn get memo => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}

@DataClassName('SyncQueueEntry')
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get localId => text()();
  TextColumn get op => textEnum<SyncOp>()();
  DateTimeColumn get enqueuedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
}

@DataClassName('KvEntry')
class KvStore extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// Design Ref: §3.1 — recurring_rules (M4 신규 v5, M5 v6 delta).
// isDue 체크: recurrenceType별 switch — monthly/weekly/daily.
// v6 delta: recurrence_type TEXT DEFAULT 'monthly', day_of_week INTEGER nullable.
@DataClassName('RecurringRuleRow')
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// FK → tx_templates. 템플릿에서 거래 prefill.
  IntColumn get templateId => integer()
      .customConstraint('NOT NULL REFERENCES tx_templates(id)')();

  /// 1-28. 29-31은 UI에서 거부. 2월 안전을 위해 최대 28일. daily/weekly에서는 무시.
  IntColumn get dayOfMonth => integer()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// 가장 최근 확인(confirm or skip) 시각. NULL = 한 번도 처리 안 함.
  DateTimeColumn get lastConfirmedAt => dateTime().nullable()();

  /// v6: 'monthly' | 'weekly' | 'daily'. DEFAULT 'monthly'.
  TextColumn get recurrenceType =>
      text().withDefault(const Constant('monthly'))();

  /// v6: 주간 반복 시 요일 (1=월~7=일, DateTime.weekday 기준). NULL = monthly/daily.
  IntColumn get dayOfWeek => integer().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// Design Ref: §3.2 — budgets (M4 신규 v5). 카테고리별 월 한도.
// UNIQUE(category_id) — 카테고리당 하나의 한도만.
@DataClassName('BudgetRow')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// FK → categories. NOT NULL UNIQUE — 카테고리당 1행.
  IntColumn get categoryId => integer()
      .customConstraint('NOT NULL UNIQUE REFERENCES categories(id)')();

  /// 원(KRW). 양수만 (UI에서 > 0 검증).
  IntColumn get monthlyLimit => integer()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// Design Ref: §3.1 — tx_templates (M3 신규 v4).
// 자주 쓰는 거래의 "껍데기"를 저장 — 사용 시 InputScreen에서 폼 prefill 후
// 일반 거래로 insert. amount는 nullable (사용 시점에 입력 가능).
@DataClassName('TxTemplate')
class TxTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 템플릿 이름. 중복 방지.
  TextColumn get name => text().unique()();

  TextColumn get type => textEnum<TxType>()();

  /// nullable — NULL이면 사용 시 사용자가 입력. 변동성 있는 고정비
  /// (전기/통신)에 유용.
  IntColumn get amount => integer().nullable()();

  IntColumn get fromAccountId => integer()
      .nullable()
      .customConstraint('NULL REFERENCES accounts(id)')();

  IntColumn get toAccountId => integer()
      .nullable()
      .customConstraint('NULL REFERENCES accounts(id)')();

  IntColumn get categoryId => integer()
      .nullable()
      .customConstraint('NULL REFERENCES categories(id)')();

  TextColumn get memo => text().nullable()();

  /// 사용자 수동 정렬 순서.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 마지막 사용 시각. picker에서 desc 정렬 (NULL은 가장 아래).
  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
