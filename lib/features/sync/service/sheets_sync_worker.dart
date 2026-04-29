// Design Ref: §4.6, §7 — workmanager periodic + app-foreground trigger.
//
// **Background isolate**: callbackDispatcher must be a top-level function
// annotated with @pragma('vm:entry-point') so the AOT compiler keeps it.
// All dependencies are reconstructed in this isolate (DB, auth, sheets).

import 'package:workmanager/workmanager.dart';

import '../../../core/db/app_database.dart';
import '../../../infrastructure/sheets/sheets_client.dart';
import '../../auth/data/google_auth_service.dart';
import '../data/sync_queue_dao.dart';
import 'sync_service.dart';

/// Task name registered with workmanager. Same constant for periodic and
/// one-off triggers (registerOneOffTask on app foreground entry).
const String sheetsSyncTaskName = 'budget-tracker-sheets-sync';

/// Background isolate entry point. Must be top-level + annotated.
@pragma('vm:entry-point')
void sheetsSyncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != sheetsSyncTaskName) return Future.value(true);

    AppDatabase? db;
    try {
      db = AppDatabase();
      final auth = GoogleAuthService()..start();
      final signedIn = await auth.signInSilently();
      if (!signedIn) return false;
      final client = await auth.authenticatedClient();
      if (client == null) return false;

      final sheets = SheetsClient(client);
      final service = SyncService(
        db: db,
        accountsDao: db.accountsDao,
        transactionsDao: db.transactionsDao,
        templatesDao: db.templatesDao,
        queueDao: SyncQueueDao(db),
        sheets: sheets,
        auth: auth,
      );

      final result = await service.flush();
      // workmanager retries when we return false; we return true on partial
      // success so it doesn't double-retry — the queue already tracks per-op
      // retries via attempt_count.
      return result.error == null;
    } catch (_) {
      return false;
    } finally {
      await db?.close();
    }
  });
}
