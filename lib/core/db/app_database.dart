// Design Ref: §3 — Drift DB v4. 6 tables, 4 DAOs registered.
// v3 delta: accounts.due_day (M2)
// v4 delta: tx_templates 테이블 신규 + categories.parent_category_id 컬럼 (M3)

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
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Accounts, Categories, Transactions, SyncQueue, KvStore, TxTemplates],
  daos: [AccountsDao, TransactionsDao, SyncQueueDao, TemplatesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 3) await V2ToV3.apply(m, this);
          // Plan SC: FR-46 — v3→v4 두 변경 동시 (templates 신규 + parent col).
          if (from < 4) await V3ToV4.apply(m, this);
        },
        beforeOpen: (details) async {
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
