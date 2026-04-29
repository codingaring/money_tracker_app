// Plan SC: FR-31 — TransactionRepository integration tests against an
// in-memory Drift database. Closes the M1 deferred testing gap (Plan §6.2).
//
// What's covered:
//   1. add expense → balance decreased + tx inserted + queue +1
//   2. add transfer → from -, to +, single tx, queue +1
//   3. add valuation → to balance set to amount, deltas stored correctly
//   4. update → previous delta undone, new delta applied (no double-counting)
//   5. delete → delta undone + soft delete (deleted_at set), queue +1

// drift exposes top-level `isNull`/`isNotNull` for SQL expression building
// which collide with flutter_test's matcher constants of the same name.
// Hide them so `expect(x, isNull)` resolves to the matcher.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/db/app_database.dart';
import 'package:money_tracker_app/features/accounts/domain/account.dart';
import 'package:money_tracker_app/features/categories/data/category_repository.dart';
import 'package:money_tracker_app/features/categories/data/category_seed.dart';
import 'package:money_tracker_app/features/sync/data/local_queue_enqueuer.dart';
import 'package:money_tracker_app/features/sync/data/sync_queue_dao.dart';
import 'package:money_tracker_app/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker_app/features/transactions/domain/transaction.dart';

void main() {
  late AppDatabase db;
  late SyncQueueDao queueDao;
  late TransactionRepository repo;
  late int bankId;
  late int cardId;
  late int foodCategoryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queueDao = SyncQueueDao(db);

    // Seed accounts: 1 cash + 1 credit_card.
    bankId = await db.accountsDao.insertOne(AccountsCompanion.insert(
      name: '신한 주거래',
      type: AccountType.cash,
      balance: const Value(1_000_000),
    ));
    cardId = await db.accountsDao.insertOne(AccountsCompanion.insert(
      name: '삼성카드',
      type: AccountType.creditCard,
      balance: const Value(0),
      dueDay: const Value(25),
    ));

    // Seed categories so expense/income tests can pick a valid category.
    await CategorySeeder(CategoryRepository(db)).run();
    final foodCat = await CategoryRepository(db).findByName('식비');
    foodCategoryId = foodCat!.id;

    repo = TransactionRepository(
      db: db,
      accountsDao: db.accountsDao,
      sync: LocalQueueEnqueuer(queueDao),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('TransactionRepository.add', () {
    test('expense decreases from_account balance + inserts tx + enqueues',
        () async {
      final tx = await repo.add(NewTransaction(
        type: TxType.expense,
        amount: 12_000,
        fromAccountId: bankId,
        categoryId: foodCategoryId,
        memo: '점심',
        occurredAt: DateTime(2026, 4, 28),
      ));

      // Balance applied (cash: 1,000,000 → 988,000).
      final bank = await db.accountsDao.findById(bankId);
      expect(bank!.balance, 988_000);

      // Tx row persisted with correct deltas.
      expect(tx.amount, 12_000);
      expect(tx.fromDelta, -12_000);
      expect(tx.toDelta, isNull);
      expect(tx.deletedAt, isNull);

      // Queue entry recorded for Sheets sync.
      expect(await queueDao.readPendingCount(), 1);
    });

    test('transfer moves balance between accounts atomically', () async {
      // Card balance starts at 0; transfer 50,000 from bank to card means a
      // credit-card payment: card(0) → +50,000 (debt reduced toward 0 already
      // here, model is symmetric), bank(-50,000).
      final tx = await repo.add(NewTransaction(
        type: TxType.transfer,
        amount: 50_000,
        fromAccountId: bankId,
        toAccountId: cardId,
        occurredAt: DateTime(2026, 4, 28),
      ));

      final bank = await db.accountsDao.findById(bankId);
      final card = await db.accountsDao.findById(cardId);
      expect(bank!.balance, 950_000);
      expect(card!.balance, 50_000);

      expect(tx.fromDelta, -50_000);
      expect(tx.toDelta, 50_000);
      expect(await queueDao.readPendingCount(), 1);
    });

    test(
        'valuation overwrites to_account balance with amount, recording delta',
        () async {
      // Re-purpose bank for clarity: pretend it's an investment with new
      // valuation. Starting balance 1,000,000; new valuation 1,250,000.
      final tx = await repo.add(NewTransaction(
        type: TxType.valuation,
        amount: 1_250_000,
        toAccountId: bankId,
        occurredAt: DateTime(2026, 4, 28),
      ));

      final bank = await db.accountsDao.findById(bankId);
      expect(bank!.balance, 1_250_000);

      // toDelta captures the change so update/delete can undo cleanly.
      expect(tx.toDelta, 250_000);
      expect(tx.fromDelta, isNull);
    });
  });

  group('TransactionRepository.update', () {
    test('undoes previous delta and applies new delta (no double-count)',
        () async {
      final original = await repo.add(NewTransaction(
        type: TxType.expense,
        amount: 10_000,
        fromAccountId: bankId,
        categoryId: foodCategoryId,
        occurredAt: DateTime(2026, 4, 28),
      ));
      // Sanity: bank 1,000,000 - 10,000 = 990,000.
      var bank = await db.accountsDao.findById(bankId);
      expect(bank!.balance, 990_000);

      // Edit amount 10,000 → 25,000.
      await repo.update(
        original,
        NewTransaction(
          type: TxType.expense,
          amount: 25_000,
          fromAccountId: bankId,
          categoryId: foodCategoryId,
          occurredAt: DateTime(2026, 4, 28),
        ),
      );

      // Expected: original 10,000 undone (+10k), then 25,000 applied (-25k):
      // 1,000,000 → 975,000.
      bank = await db.accountsDao.findById(bankId);
      expect(bank!.balance, 975_000);

      // Stored delta reflects the new value.
      final updated = await db.transactionsDao.findByLocalId(original.localId);
      expect(updated!.amount, 25_000);
      expect(updated.fromDelta, -25_000);
      // syncedAt cleared — flush will re-sync.
      expect(updated.syncedAt, isNull);
    });
  });

  group('TransactionRepository.delete', () {
    test('soft-deletes tx and undoes delta', () async {
      final tx = await repo.add(NewTransaction(
        type: TxType.expense,
        amount: 30_000,
        fromAccountId: bankId,
        categoryId: foodCategoryId,
        occurredAt: DateTime(2026, 4, 28),
      ));
      var bank = await db.accountsDao.findById(bankId);
      expect(bank!.balance, 970_000);

      await repo.delete(tx.localId);

      // Balance restored.
      bank = await db.accountsDao.findById(bankId);
      expect(bank!.balance, 1_000_000);

      // Soft delete: row still exists, but deleted_at is set.
      final after = await db.transactionsDao.findByLocalId(tx.localId);
      expect(after, isNotNull);
      expect(after!.deletedAt, isNotNull);

      // Queue contains insert + delete — flush will append + clear in order.
      expect(await queueDao.readPendingCount(), 2);
    });
  });
}
