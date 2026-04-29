// Module-6 main entry — replaces the M3/M4 sanity-check throwaway.
//
// Init order (Design §7.2):
//   1. Flutter binding
//   2. AppDatabase open + migrations applied (Drift LazyDatabase)
//   3. Categories seed (idempotent)
//   4. Workmanager init + periodic Sheets sync registration
//   5. ProviderScope (Riverpod) → App

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/db/app_database.dart';
import 'features/categories/data/category_repository.dart';
import 'features/categories/data/category_seed.dart';
import 'features/sync/service/sheets_sync_worker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open DB + run migrations (lazy connection — first query triggers it).
  final db = AppDatabase();

  // Idempotent. Safe to call on every cold start.
  await CategorySeeder(CategoryRepository(db)).run();

  // Workmanager: register the periodic sync task. The callback runs in a
  // separate isolate (sheets_sync_worker.dart) and rebuilds its own deps.
  await Workmanager().initialize(sheetsSyncCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    sheetsSyncTaskName,
    sheetsSyncTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  runApp(
    ProviderScope(
      overrides: [
        // Reuse the database instance opened above so the lazy connection
        // does not double-initialize.
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const App(),
    ),
  );
}
