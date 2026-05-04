// Design Ref: §3 — Drift DB v6. 8 tables, 4 DAOs registered.
// v3 delta: accounts.due_day (M2)
// v4 delta: tx_templates 신규 + categories.parent_category_id (M3)
// v5 delta: recurring_rules + budgets 신규 (M4)
// v6 delta: recurring_rules.recurrence_type + day_of_week (M5)

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/accounts/data/accounts_dao.dart';
import '../../features/accounts/domain/account.dart';
import '../../features/categories/domain/category.dart';
import '../../features/sync/data/sync_queue_dao.dart';
import '../../features/sync/domain/sync_op.dart';
import '../../features/templates/data/templates_dao.dart';
import '../../features/transactions/data/transactions_dao.dart';
import '../../features/transactions/domain/transaction.dart';
import 'migrations/v2_to_v3.dart';
import 'migrations/v3_to_v4.dart';
import 'migrations/v4_to_v5.dart';
import 'migrations/v5_to_v6.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    SyncQueue,
    KvStore,
    TxTemplates,
    RecurringRules,
    Budgets,
  ],
  daos: [AccountsDao, TransactionsDao, SyncQueueDao, TemplatesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 3) await V2ToV3.apply(m, this);
          // Plan SC: FR-46 — v3→v4 두 변경 동시 (templates 신규 + parent col).
          if (from < 4) await V3ToV4.apply(m, this);
          if (from < 5) await V4ToV5.apply(m, this);
          if (from < 6) await V5ToV6.apply(m, this);
        },
        beforeOpen: (details) async {
          // WAL mode required for Drift reactive watch() on Android —
          // SQLite update hook is unreliable in DELETE journal mode.
          await customStatement('PRAGMA journal_mode=WAL');
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'money_tracker.sqlite'));
    return NativeDatabase(file);
  });
}
