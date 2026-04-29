// Design Ref: §3.6 — 3-sheet layout (transactions append / accounts snapshot /
// monthly_summary aggregate).
//
// All sheet names, headers, and column ranges live here so changes propagate
// in one place and tests can verify drift between schema and Sheets layout.

class SheetLayout {
  const SheetLayout._();

  /// Spreadsheet title shown in the user's Google Drive.
  static const String spreadsheetTitle = 'Money Tracker';

  // ── Sheet names (English — chosen for cleaner range expressions) ───────────
  static const String txSheet = 'transactions';
  static const String accountsSheet = 'accounts';
  static const String monthlySheet = 'monthly_summary';
  static const String templatesSheet = 'templates'; // M3

  // ── Headers ────────────────────────────────────────────────────────────────
  /// Column order MUST match [SheetLayout.txIdColIdx] and tx-to-row mapping.
  /// M3: D 위치에 `category_parent` 신규 컬럼. 9 → 10 cols.
  static const List<String> txHeader = [
    'date',            // A — occurred_at ISO string
    'type',            // B — TxType.name
    'amount',          // C
    'category_parent', // D — 🆕 M3: parent category name (NULL이면 빈 문자열)
    'category',        // E — leaf category name (parent NULL이면 자기 자신)
    'from_account',    // F — account name
    'to_account',      // G — account name
    'memo',            // H
    'tx_id',           // I — local_id (UUID) — row matching key
    'synced_at',       // J — DateTime ISO
  ];

  // Design Ref: M2 §8.1 — accounts sheet column 'due_day' added in v3.
  // Existing user sheets are auto-extended on next overwrite (header row is
  // rewritten). Empty G column for non-credit_card accounts is intentional.
  static const List<String> accountsHeader = [
    'name',           // A
    'type',           // B — AccountType.name
    'balance',        // C
    'parent_account', // D — parent name or empty
    'is_active',      // E — TRUE/FALSE
    'updated_at',     // F
    'due_day',        // G — credit_card 결제일 (1-31) or empty
  ];

  static const List<String> monthlyHeader = [
    'year_month',     // A — 'YYYY-MM'
    'income',         // B
    'expense',        // C
    'net',            // D
    'net_worth_end',  // E
  ];

  /// M3: tx_templates snapshot. 9 cols.
  static const List<String> templatesHeader = [
    'name',           // A
    'type',           // B — TxType.name
    'amount',         // C — int 또는 빈 문자열 (NULL)
    'from_account',   // D
    'to_account',     // E
    'category',       // F — leaf category (parent 정보 없음)
    'memo',           // G
    'sort_order',     // H
    'last_used_at',   // I — DateTime ISO 또는 빈 문자열
  ];

  // ── Column ranges ──────────────────────────────────────────────────────────
  /// Range used for `values.append` on the transactions sheet.
  /// M3: 9 → 10 cols (A:I → A:J — `category_parent` 추가).
  static const String txAppendRange = "$txSheet!A:J";

  /// Used by [SheetsClient.findRowByLocalId] — column I (1-based 9) holds tx_id.
  /// M3: H → I (D 위치 신규 컬럼 삽입으로 한 칸씩 밀림).
  static const String txIdSearchRange = "$txSheet!I:I";

  /// 0-indexed position of tx_id in [txHeader].
  /// M3: 7 → 8.
  static const int txIdColIdx = 8;

  /// Full table range for accounts snapshot overwrite (header + data).
  /// M2 v3 expanded to A:G — must include the new due_day column.
  static const String accountsOverwriteRange = "$accountsSheet!A1:G";

  /// Full table range for monthly_summary overwrite (header + data).
  static const String monthlyOverwriteRange = "$monthlySheet!A1:E";

  /// M3: templates snapshot — 9 cols.
  static const String templatesOverwriteRange = "$templatesSheet!A1:I";

  // ── OAuth scopes ───────────────────────────────────────────────────────────
  /// `drive.file` is restricted to files this app created — no Google
  /// verification review required.
  static const List<String> oauthScopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.file',
  ];

  /// Build a range like `'transactions!A42:J42'` for a specific row.
  /// M3: I → J.
  static String txRowRange(int rowIndex) => "$txSheet!A$rowIndex:J$rowIndex";
}
