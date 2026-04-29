// Design Ref: §4.8 — googleapis Sheets v4 adapter.
// **No business logic here** — retry policy, queue management, and 3-sheet
// orchestration all live in SyncService.

import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;

import 'sheet_layout.dart';

class SheetsClient {
  SheetsClient(gauth.AuthClient authClient)
      : _api = sheets.SheetsApi(authClient);

  final sheets.SheetsApi _api;

  /// Creates a new spreadsheet titled per [SheetLayout.spreadsheetTitle].
  /// Returns the new spreadsheet id.
  Future<String> createSpreadsheet({String? title}) async {
    final created = await _api.spreadsheets.create(
      sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(
          title: title ?? SheetLayout.spreadsheetTitle,
        ),
      ),
    );
    final id = created.spreadsheetId;
    if (id == null) {
      throw StateError('Sheets API returned no spreadsheetId');
    }
    return id;
  }

  /// Idempotent. If [sheetName] is missing, adds it via batchUpdate and writes
  /// the header row. If present, ensures the header matches by overwriting row 1.
  Future<void> ensureSheet(
    String spreadsheetId,
    String sheetName,
    List<String> header,
  ) async {
    final meta = await _api.spreadsheets.get(spreadsheetId);
    final existing = meta.sheets
            ?.where((s) => s.properties?.title == sheetName)
            .toList() ??
        const [];

    if (existing.isEmpty) {
      await _api.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: [
          sheets.Request(
            addSheet: sheets.AddSheetRequest(
              properties: sheets.SheetProperties(title: sheetName),
            ),
          ),
        ]),
        spreadsheetId,
      );
    }

    // Always rewrite header row 1 (cheap and self-healing).
    final endCol = _columnLetter(header.length);
    await _api.spreadsheets.values.update(
      sheets.ValueRange(values: [header]),
      spreadsheetId,
      "$sheetName!A1:${endCol}1",
      valueInputOption: 'USER_ENTERED',
    );
  }

  /// Append rows below the existing data on [range].
  Future<void> appendRows(
    String spreadsheetId,
    String range,
    List<List<Object?>> rows,
  ) async {
    if (rows.isEmpty) return;
    await _api.spreadsheets.values.append(
      sheets.ValueRange(values: rows),
      spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
    );
  }

  /// Linear scan of the search range looking for [localId]. Returns the
  /// 1-based row index in Sheets (header is row 1, data starts row 2), or
  /// null if not found.
  ///
  /// Caller should LRU-cache results; this is O(N) over the column.
  Future<int?> findRowByLocalId(
    String spreadsheetId,
    String searchRange,
    String localId,
  ) async {
    final result = await _api.spreadsheets.values.get(
      spreadsheetId,
      searchRange,
    );
    final rows = result.values;
    if (rows == null) return null;
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.isNotEmpty && row.first?.toString() == localId) {
        // i is 0-based, Sheets row index is 1-based.
        return i + 1;
      }
    }
    return null;
  }

  /// Replace a single row. [range] like `transactions!A42:I42`.
  Future<void> updateRow(
    String spreadsheetId,
    String range,
    List<Object?> row,
  ) async {
    await _api.spreadsheets.values.update(
      sheets.ValueRange(values: [row]),
      spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );
  }

  /// Clear cell values on [range] without removing the row (preserves sort
  /// order of the user's other queries — design §4.6 delete strategy).
  Future<void> clearRange(String spreadsheetId, String range) async {
    await _api.spreadsheets.values.clear(
      sheets.ClearValuesRequest(),
      spreadsheetId,
      range,
    );
  }

  /// Replace [range] entirely with [values]. Used for accounts snapshot and
  /// monthly_summary aggregate (design §4.6).
  Future<void> overwriteRange(
    String spreadsheetId,
    String range,
    List<List<Object?>> values,
  ) async {
    // Clear first so trailing rows from a previous larger payload are removed.
    await _api.spreadsheets.values.clear(
      sheets.ClearValuesRequest(),
      spreadsheetId,
      range,
    );
    if (values.isEmpty) return;
    await _api.spreadsheets.values.update(
      sheets.ValueRange(values: values),
      spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );
  }

  /// 1 → 'A', 2 → 'B', ..., 26 → 'Z'. We never exceed Z in this project.
  static String _columnLetter(int n) {
    assert(n >= 1 && n <= 26, 'unsupported column count $n');
    return String.fromCharCode('A'.codeUnitAt(0) + n - 1);
  }
}
