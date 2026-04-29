// Design Ref: §4.5 — Reactive 7-metric stream wired to Drift table updates.
// Plan SC: FR-08 — dashboard 즉시 반영 (입력 후 ≤ 100ms).

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../accounts/data/accounts_dao.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/dashboard_metrics.dart';

class DashboardRepository {
  DashboardRepository({
    required AppDatabase db,
    required AccountsDao accountsDao,
  })  : _db = db,
        _accountsDao = accountsDao;

  final AppDatabase _db;
  final AccountsDao _accountsDao;

  /// Reactive stream — re-aggregates whenever accounts or transactions change.
  /// Emits an initial value immediately on subscription.
  Stream<DashboardMetrics> watchMetrics() async* {
    yield await _computeOnce();
    final updates = _db.tableUpdates(TableUpdateQuery.onAllTables([
      _db.accounts,
      _db.transactions,
    ]));
    await for (final _ in updates) {
      yield await _computeOnce();
    }
  }

  /// One-shot read — useful for pull-to-refresh or initial paint.
  Future<DashboardMetrics> read() => _computeOnce();

  Future<DashboardMetrics> _computeOnce() async {
    final accounts = await _accountsDao.readAll(activeOnly: true);
    final monthly = await _readMonthlyTotals();
    return DashboardMetrics.compute(
      accounts: accounts,
      currentMonthIncome: monthly.income,
      currentMonthExpense: monthly.expense,
    );
  }

  Future<({int income, int expense})> _readMonthlyTotals({
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final firstDay = DateTime(today.year, today.month);
    final firstDayNext = DateTime(today.year, today.month + 1);

    final txs = await (_db.select(_db.transactions)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.occurredAt.isBiggerOrEqualValue(firstDay) &
              t.occurredAt.isSmallerThanValue(firstDayNext)))
        .get();

    var income = 0;
    var expense = 0;
    for (final t in txs) {
      if (t.type == TxType.income) {
        income += t.amount;
      } else if (t.type == TxType.expense) {
        expense += t.amount;
      }
    }
    return (income: income, expense: expense);
  }
}
