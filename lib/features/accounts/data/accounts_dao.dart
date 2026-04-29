// Design Ref: §4.2 — Single entry point for balance changes.
// **Invariant**: accounts.balance is changed ONLY via this DAO.
// Direct `update(accounts)` from Repository is forbidden.

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/tables.dart';

part 'accounts_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.db);

  Stream<List<Account>> watchAll({bool activeOnly = true}) {
    final q = select(accounts);
    if (activeOnly) {
      q.where((a) => a.isActive.equals(true));
    }
    q.orderBy([
      (a) => OrderingTerm.asc(a.sortOrder),
      (a) => OrderingTerm.asc(a.name),
    ]);
    return q.watch();
  }

  Future<List<Account>> readAll({bool activeOnly = false}) {
    final q = select(accounts);
    if (activeOnly) {
      q.where((a) => a.isActive.equals(true));
    }
    q.orderBy([(a) => OrderingTerm.asc(a.id)]);
    return q.get();
  }

  Future<Account?> findById(int id) {
    return (select(accounts)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Account?> findByName(String name) {
    return (select(accounts)..where((a) => a.name.equals(name)))
        .getSingleOrNull();
  }

  Future<int> insertOne(AccountsCompanion data) {
    return into(accounts).insert(data);
  }

  Future<int> updateMeta(int id, AccountsCompanion patch) {
    // patch must NOT include `balance`; balance changes go through
    // adjustBalance/setBalance only.
    assert(!patch.balance.present, 'use adjustBalance/setBalance for balance');
    return (update(accounts)..where((a) => a.id.equals(id))).write(
      patch.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  Future<int?> readBalance(int id) async {
    final row = await findById(id);
    return row?.balance;
  }

  /// Atomic increment/decrement. Used for expense/income/transfer.
  /// Caller must wrap in db.transaction for cross-account consistency.
  ///
  /// updated_at uses SQL strftime to match the column's INT (Unix epoch)
  /// storage — must NOT pass an ISO string here, or [SqlTypes.read] will
  /// later try to int.parse it and throw FormatException.
  Future<void> adjustBalance(int id, int delta) async {
    if (delta == 0) return;
    await customStatement(
      "UPDATE accounts "
      "SET balance = balance + ?, updated_at = strftime('%s', 'now') "
      "WHERE id = ?",
      [delta, id],
    );
  }

  /// Used by valuation: returns the previous balance so caller can compute delta.
  /// Caller must wrap in db.transaction.
  Future<int> setBalance(int id, int newBalance) async {
    final prev = await readBalance(id) ?? 0;
    await (update(accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        balance: Value(newBalance),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return prev;
  }
}
