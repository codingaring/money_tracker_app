// Design Ref: §4.1 AccountRepository — CRUD + active toggle.
// Balance writes are NOT exposed here; they go through AccountsDao only,
// invoked from TransactionRepository inside a db.transaction.

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../domain/account.dart';
import 'accounts_dao.dart';
import 'balance_reconciler.dart';

class AccountRepository {
  AccountRepository({
    required AppDatabase db,
    required AccountsDao dao,
    BalanceReconciler? reconciler,
  })  : _db = db,
        _dao = dao,
        _reconciler =
            reconciler ?? BalanceReconciler(db: db, accountsDao: dao);

  final AppDatabase _db;
  final AccountsDao _dao;
  final BalanceReconciler _reconciler;

  Stream<List<Account>> watchAll({bool activeOnly = true}) =>
      _dao.watchAll(activeOnly: activeOnly);

  Future<Account?> findById(int id) => _dao.findById(id);

  Future<Account> create({
    required String name,
    required AccountType type,
    int initialBalance = 0,
    int sortOrder = 0,
    int? parentAccountId,
    int? dueDay,
    String? note,
  }) async {
    return _db.transaction(() async {
      final id = await _dao.insertOne(AccountsCompanion.insert(
        name: name,
        type: type,
        balance: Value(initialBalance),
        sortOrder: Value(sortOrder),
        parentAccountId: Value(parentAccountId),
        dueDay: Value(_normalizeDueDay(dueDay, type)),
        note: Value(note),
      ));
      // Plan SC: FR-18 — record opening balance so the reconciler can
      // distinguish "initial" from "applied deltas" later.
      await _reconciler.recordInitialBalance(id, initialBalance);
      final created = await _dao.findById(id);
      if (created == null) {
        throw StateError('Inserted account not found id=$id');
      }
      return created;
    });
  }

  /// Updates non-balance metadata. Balance must be changed via a [TxType.valuation]
  /// transaction so the audit trail and Sheets mirror stay consistent.
  ///
  /// Use sentinel [Value.absent] semantics by passing `null` for "no change".
  /// To explicitly clear a nullable column (e.g., remove parent or due_day) use
  /// [clearParent]/[clearDueDay] flags.
  Future<void> updateMeta(
    int id, {
    String? name,
    AccountType? type,
    int? sortOrder,
    int? parentAccountId,
    bool clearParent = false,
    int? dueDay,
    bool clearDueDay = false,
    String? note,
    bool? isActive,
  }) {
    return _dao.updateMeta(
      id,
      AccountsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        type: type == null ? const Value.absent() : Value(type),
        sortOrder:
            sortOrder == null ? const Value.absent() : Value(sortOrder),
        parentAccountId: clearParent
            ? const Value(null)
            : (parentAccountId == null
                ? const Value.absent()
                : Value(parentAccountId)),
        dueDay: clearDueDay
            ? const Value(null)
            : (dueDay == null
                ? const Value.absent()
                : Value(_normalizeDueDay(dueDay, type))),
        note: note == null ? const Value.absent() : Value(note),
        isActive: isActive == null ? const Value.absent() : Value(isActive),
      ),
    );
  }

  Future<void> deactivate(int id) => updateMeta(id, isActive: false);

  /// Clamp 1-31 into 1-28 to keep [computeNextDueDate] safe in February.
  /// Non-credit_card type forces NULL via UI; this is a defense-in-depth.
  static int? _normalizeDueDay(int? day, AccountType? type) {
    if (day == null) return null;
    if (type != null && type != AccountType.creditCard) return null;
    return day.clamp(1, 28);
  }
}
