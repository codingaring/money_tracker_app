// Design Ref: §4.2 — CardDetailRepository.
// 읽기 전용. 카드 한정 metrics 조립 (DAO read + 결제일 계산).

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/account.dart';
import '../domain/card_detail_metrics.dart';
import 'accounts_dao.dart';

class CardDetailRepository {
  CardDetailRepository({
    required AppDatabase db,
    required AccountsDao accountsDao,
  }) : _db = db,
       _accountsDao = accountsDao;

  final AppDatabase _db;
  final AccountsDao _accountsDao;

  /// Plan SC: SC-1 — assembles metrics for [accountId]. Throws if the account
  /// is missing or not a credit_card (caller should only invoke for cards).
  Future<CardDetailMetrics> compute(int accountId, {DateTime? now}) async {
    final today = now ?? DateTime.now();
    final account = await _accountsDao.findById(accountId);
    if (account == null) {
      throw ArgumentError('account not found: $accountId');
    }
    if (account.type != AccountType.creditCard) {
      throw ArgumentError(
        'CardDetailRepository requires credit_card, got ${account.type}',
      );
    }

    final monthStart = DateTime(today.year, today.month);
    final monthEnd = DateTime(today.year, today.month + 1);
    final results = await Future.wait([
      _sumThisMonthCharges(accountId, monthStart, monthEnd),
      _recentCharges(accountId, limit: 10),
    ]);
    final thisMonthSum = results[0] as int;
    final recent = results[1] as List<TxRow>;

    final nextDue = computeNextDueDate(account.dueDay, today);
    return CardDetailMetrics(
      account: account,
      currentMonthCharges: thisMonthSum,
      nextDueDate: nextDue,
      daysUntilDue: nextDue == null
          ? -1
          : nextDue.difference(_atMidnight(today)).inDays,
      // balance < 0 means we owe; flip sign for the user-facing label.
      expectedPayment: account.balance < 0 ? -account.balance : 0,
      recentCharges: recent,
    );
  }

  /// Sum of expense [amount] for txns with [fromAccountId] = accountId in
  /// the [start, end) interval. Stored amount is positive — the sign comes
  /// from [TxType.expense] semantics — so we sum amount directly.
  Future<int> _sumThisMonthCharges(
    int accountId,
    DateTime start,
    DateTime end,
  ) async {
    final amount = _db.transactions.amount;
    final exp = amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([exp])
      ..where(
        _db.transactions.deletedAt.isNull() &
            _db.transactions.type.equalsValue(TxType.expense) &
            _db.transactions.fromAccountId.equals(accountId) &
            _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
            _db.transactions.occurredAt.isSmallerThanValue(end),
      );
    final row = await query.getSingleOrNull();
    return row?.read(exp) ?? 0;
  }

  Future<List<TxRow>> _recentCharges(int accountId, {required int limit}) {
    return (_db.select(_db.transactions)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                (t.fromAccountId.equals(accountId) |
                    t.toAccountId.equals(accountId)),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(limit))
        .get();
  }

  /// Pure function — testable without DB.
  ///
  /// Returns the next occurrence of [dueDay] on or after [today].
  /// - `null` when [dueDay] is null.
  /// - Day clamped to 1-28 to stay safe across all months (FR-21 docs).
  /// - When today already matches [dueDay], returns today (D-0).
  static DateTime? computeNextDueDate(int? dueDay, DateTime today) {
    if (dueDay == null) return null;
    final clamped = dueDay.clamp(1, 28);
    final midnightToday = DateTime(today.year, today.month, today.day);
    var next = DateTime(today.year, today.month, clamped);
    if (next.isBefore(midnightToday)) {
      next = DateTime(today.year, today.month + 1, clamped);
    }
    return next;
  }

  static DateTime _atMidnight(DateTime t) => DateTime(t.year, t.month, t.day);
}
