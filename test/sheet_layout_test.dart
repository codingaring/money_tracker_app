// Module-3 unit test — guards against accidental drift between Sheets layout
// constants and the SyncService row mapping.

import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/infrastructure/sheets/sheet_layout.dart';

void main() {
  group('SheetLayout', () {
    test('spreadsheet title matches user-confirmed value', () {
      expect(SheetLayout.spreadsheetTitle, 'Money Tracker');
    });

    test('sheet names are English (chosen by user)', () {
      expect(SheetLayout.txSheet, 'transactions');
      expect(SheetLayout.accountsSheet, 'accounts');
      expect(SheetLayout.monthlySheet, 'monthly_summary');
      expect(SheetLayout.templatesSheet, 'templates'); // M3
    });

    test('tx header has 10 columns (M3: +category_parent at D)', () {
      expect(SheetLayout.txHeader, [
        'date',
        'type',
        'amount',
        'category_parent', // M3 신규
        'category',
        'from_account',
        'to_account',
        'memo',
        'tx_id',
        'synced_at',
      ]);
      expect(SheetLayout.txHeader.length, 10);
    });

    test('tx_id column index matches header position', () {
      expect(SheetLayout.txHeader[SheetLayout.txIdColIdx], 'tx_id');
    });

    test('templates header has 9 columns (M3 신규)', () {
      expect(SheetLayout.templatesHeader, [
        'name',
        'type',
        'amount',
        'from_account',
        'to_account',
        'category',
        'memo',
        'sort_order',
        'last_used_at',
      ]);
    });

    test('accounts header has 7 columns (M2 v3: +due_day)', () {
      expect(SheetLayout.accountsHeader, [
        'name',
        'type',
        'balance',
        'parent_account',
        'is_active',
        'updated_at',
        'due_day',
      ]);
    });

    test('monthly header has 5 columns', () {
      expect(SheetLayout.monthlyHeader, [
        'year_month',
        'income',
        'expense',
        'net',
        'net_worth_end',
      ]);
    });

    test('range constants align with header column counts (M3 updated)', () {
      expect(SheetLayout.txAppendRange, 'transactions!A:J'); // 10 cols (M3)
      expect(SheetLayout.txIdSearchRange, 'transactions!I:I'); // M3: H → I
      expect(SheetLayout.accountsOverwriteRange, 'accounts!A1:G'); // 7 cols (M2)
      expect(SheetLayout.monthlyOverwriteRange,
          'monthly_summary!A1:E'); // 5 cols
      expect(SheetLayout.templatesOverwriteRange,
          'templates!A1:I'); // 9 cols (M3)
    });

    test('txRowRange builds correct range for a row (M3: A:J)', () {
      expect(SheetLayout.txRowRange(42), 'transactions!A42:J42');
      expect(SheetLayout.txRowRange(2), 'transactions!A2:J2');
    });

    test('OAuth scopes use drive.file (no Google review required)', () {
      expect(SheetLayout.oauthScopes, contains(
        'https://www.googleapis.com/auth/spreadsheets',
      ));
      expect(SheetLayout.oauthScopes, contains(
        'https://www.googleapis.com/auth/drive.file',
      ));
      expect(SheetLayout.oauthScopes, isNot(contains(
        'https://www.googleapis.com/auth/drive', // would require verification
      )));
    });
  });
}
