// Module-2 unit test — NewTransaction DTO + type-specific validation.

import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/features/transactions/domain/transaction.dart';

void main() {
  final at = DateTime(2026, 4, 28, 14, 32);

  group('TxType enum', () {
    test('exposes 4 values in detail.md order', () {
      expect(TxType.values.map((e) => e.name), [
        'expense',
        'income',
        'transfer',
        'valuation',
      ]);
    });
  });

  group('NewTransaction.validate — happy paths', () {
    test('expense with from + category', () {
      final tx = NewTransaction(
        type: TxType.expense,
        amount: 12000,
        fromAccountId: 1,
        categoryId: 10,
        occurredAt: at,
      );
      expect(tx.validate(), isNull);
    });

    test('income with to + category', () {
      final tx = NewTransaction(
        type: TxType.income,
        amount: 3200000,
        toAccountId: 1,
        categoryId: 50,
        occurredAt: at,
      );
      expect(tx.validate(), isNull);
    });

    test('transfer with from + to (different)', () {
      final tx = NewTransaction(
        type: TxType.transfer,
        amount: 150000,
        fromAccountId: 1,
        toAccountId: 2,
        occurredAt: at,
      );
      expect(tx.validate(), isNull);
    });

    test('valuation with to only', () {
      final tx = NewTransaction(
        type: TxType.valuation,
        amount: 1200000,
        toAccountId: 3,
        occurredAt: at,
      );
      expect(tx.validate(), isNull);
    });
  });

  group('NewTransaction.validate — violations', () {
    test('amount must be positive', () {
      final tx = NewTransaction(
        type: TxType.expense,
        amount: 0,
        fromAccountId: 1,
        categoryId: 10,
        occurredAt: at,
      );
      expect(tx.validate(), contains('amount'));
    });

    test('expense without fromAccountId', () {
      final tx = NewTransaction(
        type: TxType.expense,
        amount: 100,
        categoryId: 10,
        occurredAt: at,
      );
      expect(tx.validate(), contains('fromAccountId'));
    });

    test('expense with toAccountId is rejected', () {
      final tx = NewTransaction(
        type: TxType.expense,
        amount: 100,
        fromAccountId: 1,
        toAccountId: 2,
        categoryId: 10,
        occurredAt: at,
      );
      expect(tx.validate(), contains('toAccountId'));
    });

    test('income without categoryId', () {
      final tx = NewTransaction(
        type: TxType.income,
        amount: 100,
        toAccountId: 1,
        occurredAt: at,
      );
      expect(tx.validate(), contains('categoryId'));
    });

    test('transfer with same from and to', () {
      final tx = NewTransaction(
        type: TxType.transfer,
        amount: 100,
        fromAccountId: 5,
        toAccountId: 5,
        occurredAt: at,
      );
      expect(tx.validate(), contains('differ'));
    });

    test('transfer with categoryId is rejected', () {
      final tx = NewTransaction(
        type: TxType.transfer,
        amount: 100,
        fromAccountId: 1,
        toAccountId: 2,
        categoryId: 10,
        occurredAt: at,
      );
      expect(tx.validate(), contains('categoryId'));
    });

    test('valuation with fromAccountId is rejected', () {
      final tx = NewTransaction(
        type: TxType.valuation,
        amount: 100,
        fromAccountId: 1,
        toAccountId: 2,
        occurredAt: at,
      );
      expect(tx.validate(), contains('fromAccountId'));
    });
  });
}
