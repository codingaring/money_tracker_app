// Design Ref: §7 — Riverpod provider catalog.
// Single source of DI. Repositories/services are read-only after construction;
// per-call state lives in NotifierProviders within feature/ui modules (M7).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';
import '../features/accounts/data/account_repository.dart';
import '../features/accounts/data/accounts_dao.dart';
import '../features/accounts/data/balance_reconciler.dart';
import '../features/accounts/data/card_detail_repository.dart';
import '../features/accounts/domain/card_detail_metrics.dart';
import '../features/analytics/data/analytics_repository.dart';
import '../features/analytics/data/budget_repository.dart';
import '../features/analytics/domain/category_segment.dart';
import '../features/analytics/domain/monthly_split_series.dart';
// M5 Report DTOs (defined inline in analytics_repository.dart)
import '../features/auth/data/google_auth_service.dart';
import '../features/categories/data/category_repository.dart';
import '../features/categories/domain/category.dart';
import '../features/dashboard/data/dashboard_repository.dart';
import '../features/dashboard/data/recurring_rule_repository.dart';
import '../features/dashboard/domain/dashboard_metrics.dart';
import '../features/sync/data/local_queue_enqueuer.dart';
import '../features/sync/data/sync_queue_dao.dart';
import '../features/sync/domain/sync_enqueuer.dart';
import '../features/templates/data/template_repository.dart';
import '../features/templates/data/templates_dao.dart';
import '../features/transactions/data/transaction_repository.dart';
import '../features/transactions/data/transactions_dao.dart';
import '../features/transactions/domain/search_filter.dart';
import '../features/transactions/domain/transaction.dart';

// ── DB / DAOs ────────────────────────────────────────────────────────────────

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final accountsDaoProvider = Provider<AccountsDao>(
  (ref) => ref.watch(appDatabaseProvider).accountsDao,
);

final transactionsDaoProvider = Provider<TransactionsDao>(
  (ref) => ref.watch(appDatabaseProvider).transactionsDao,
);

final syncQueueDaoProvider = Provider<SyncQueueDao>(
  (ref) => SyncQueueDao(ref.watch(appDatabaseProvider)),
);

// ── Repositories ─────────────────────────────────────────────────────────────

final balanceReconcilerProvider = Provider<BalanceReconciler>((ref) {
  return BalanceReconciler(
    db: ref.watch(appDatabaseProvider),
    accountsDao: ref.watch(accountsDaoProvider),
  );
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    db: ref.watch(appDatabaseProvider),
    dao: ref.watch(accountsDaoProvider),
    reconciler: ref.watch(balanceReconcilerProvider),
  );
});

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(appDatabaseProvider)),
);

final syncEnqueuerProvider = Provider<SyncEnqueuer>(
  (ref) => LocalQueueEnqueuer(ref.watch(syncQueueDaoProvider)),
);

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(
    db: ref.watch(appDatabaseProvider),
    accountsDao: ref.watch(accountsDaoProvider),
    sync: ref.watch(syncEnqueuerProvider),
  );
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    db: ref.watch(appDatabaseProvider),
    accountsDao: ref.watch(accountsDaoProvider),
  );
});

// Design Ref: §6 — CardDetail providers (M2 schema-card).
final cardDetailRepositoryProvider = Provider<CardDetailRepository>((ref) {
  return CardDetailRepository(
    db: ref.watch(appDatabaseProvider),
    accountsDao: ref.watch(accountsDaoProvider),
  );
});

final cardDetailProvider = FutureProvider.family<CardDetailMetrics, int>((
  ref,
  accountId,
) async {
  // Recompute when transactions or accounts change so D-day, current-month
  // charges and recent list stay live.
  ref.watch(transactionsStreamProvider);
  ref.watch(accountsStreamProvider);
  return ref.watch(cardDetailRepositoryProvider).compute(accountId);
});

// Design Ref: §6 — Analytics providers (M2 analytics-tab).
final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(ref.watch(appDatabaseProvider)),
);

final categoryDonutProvider =
    FutureProvider.family<List<CategorySegment>, DateTime>((ref, month) async {
      ref.watch(transactionsStreamProvider);
      return ref.watch(analyticsRepositoryProvider).categoryDonut(month: month);
    });

/// Last 6 months expense split. Refresh on transaction changes.
final fixedVariableSeriesProvider = FutureProvider<List<MonthlySplitSeries>>((
  ref,
) async {
  ref.watch(transactionsStreamProvider);
  return ref.watch(analyticsRepositoryProvider).fixedVariableSeries(months: 6);
});

/// M3 calendar — 월별 일자별 expense 합계.
/// transactionsStreamProvider watch로 거래 추가/삭제 시 자동 재계산.
final dailyExpenseMapProvider =
    FutureProvider.family<Map<DateTime, int>, DateTime>((ref, month) async {
  ref.watch(transactionsStreamProvider);
  return ref
      .watch(analyticsRepositoryProvider)
      .dailyExpenseMap(month: month);
});

// Design Ref: §6 — Search providers (M2 search-filter).

class SearchFilterNotifier extends Notifier<SearchFilter> {
  @override
  SearchFilter build() => const SearchFilter();

  void setKeyword(String keyword) {
    state = state.copyWith(keyword: keyword);
  }

  void setDateRange(DateRange range) {
    state = state.copyWith(dateRange: range);
  }

  void clearDate() {
    state = state.copyWith(clearDate: true);
  }

  void setAccount({required int id, required String name}) {
    state = state.copyWith(accountId: id, accountName: name);
  }

  void clearAccount() {
    state = state.copyWith(clearAccount: true);
  }

  void setCategory({required int id, required String name}) {
    state = state.copyWith(categoryId: id, categoryName: name);
  }

  void clearCategory() {
    state = state.copyWith(clearCategory: true);
  }

  void setType(TxType type) {
    state = state.copyWith(type: type);
  }

  void clearType() {
    state = state.copyWith(clearType: true);
  }

  void reset() {
    state = const SearchFilter();
  }
}

final searchFilterProvider =
    NotifierProvider<SearchFilterNotifier, SearchFilter>(
      SearchFilterNotifier.new,
    );

/// Search results — only invoked while the filter is non-empty.
/// `transactionsStreamProvider` is watched as well so newly-added/edited
/// transactions are reflected without manual refresh.
final searchResultsProvider = FutureProvider<List<TxRow>>((ref) async {
  final filter = ref.watch(searchFilterProvider);
  if (filter.isEmpty) return const [];
  ref.watch(transactionsStreamProvider);
  return ref
      .watch(transactionsDaoProvider)
      .search(
        keyword: filter.keyword,
        from: filter.dateRange.from,
        to: filter.dateRange.to,
        accountId: filter.accountId,
        categoryId: filter.categoryId,
        type: filter.type,
      );
});

final categoriesListProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);

// Design Ref: §6 — Templates providers (M3 schema-template).
final templatesDaoProvider = Provider<TemplatesDao>(
  (ref) => ref.watch(appDatabaseProvider).templatesDao,
);

final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => TemplateRepository(dao: ref.watch(templatesDaoProvider)),
);

/// TemplatesScreen 용 — sortOrder 정렬.
final templatesListProvider = StreamProvider<List<TxTemplate>>(
  (ref) => ref.watch(templateRepositoryProvider).watchAll(),
);

/// TemplatePickerSheet 용 — lastUsedAt desc (NULL은 마지막).
final templatesByLastUsedProvider = StreamProvider<List<TxTemplate>>(
  (ref) => ref.watch(templateRepositoryProvider).watchByLastUsed(),
);

// Design Ref: §6 — Category hierarchy providers (M3 schema).
// Stream 기반 — create/update/delete/reorder 시 UI 자동 갱신 (Drift 변경 알림).
/// 대분류만 (parent NULL). CategoryPicker 1단 + CategoryFormSheet 부모 dropdown.
final topLevelCategoriesProvider =
    StreamProvider.family<List<Category>, CategoryKind>(
  (ref, kind) =>
      ref.watch(categoryRepositoryProvider).watchTopLevel(kind: kind),
);

/// 특정 부모의 자식. CategoryPicker 2단.
final categoryChildrenProvider =
    StreamProvider.family<List<Category>, int>(
  (ref, parentId) =>
      ref.watch(categoryRepositoryProvider).watchChildren(parentId),
);

/// CategoryPicker가 단일 쿼리로 (top + children + parent lookup)을 처리하기
/// 위해 사용. M3 categoriesByKindProvider — 같은 kind의 모든 카테고리.
final categoriesByKindProvider =
    StreamProvider.family<List<Category>, CategoryKind>(
  (ref, kind) => ref.watch(categoryRepositoryProvider).watchAll(kind: kind),
);

// ── Reactive streams ─────────────────────────────────────────────────────────

final dashboardMetricsProvider = StreamProvider<DashboardMetrics>(
  (ref) => ref.watch(dashboardRepositoryProvider).watchMetrics(),
);

final accountsStreamProvider = StreamProvider(
  (ref) => ref.watch(accountsDaoProvider).watchAll(),
);

final transactionsStreamProvider = StreamProvider(
  (ref) => ref.watch(transactionsDaoProvider).watchAll(limit: 100),
);

final syncPendingCountProvider = StreamProvider<int>(
  (ref) => ref.watch(syncQueueDaoProvider).watchPendingCount(),
);

// ── Auth ─────────────────────────────────────────────────────────────────────

final googleAuthProvider = Provider<GoogleAuthService>((ref) {
  final svc = GoogleAuthService()..start();
  ref.onDispose(svc.dispose);
  return svc;
});

final authSignedInProvider = StreamProvider<bool>(
  (ref) => ref.watch(googleAuthProvider).watchSignedIn(),
);

// ── Recurring Rules ───────────────────────────────────────────────────────────

// Design Ref: §6 — recurring providers (M4).
final recurringRuleRepositoryProvider = Provider<RecurringRuleRepository>(
  (ref) => RecurringRuleRepository(ref.watch(appDatabaseProvider)),
);

final allRecurringRulesProvider = StreamProvider<List<RecurringRule>>(
  (ref) => ref.watch(recurringRuleRepositoryProvider).watchAll(),
);

/// today 기준 isDue == true인 규칙만. allRecurringRules 변경 시 자동 재계산.
final dueRecurringRulesProvider = Provider<List<RecurringRule>>((ref) {
  final today = DateTime.now();
  return ref
          .watch(allRecurringRulesProvider)
          .valueOrNull
          ?.where((r) => r.isDue(today))
          .toList() ??
      const [];
});

// ── M5 Report Providers ───────────────────────────────────────────────────────

// Design Ref: §6 — Report providers (M5). FutureProvider.family<T, int(year)>.

final monthlyTrendProvider =
    FutureProvider.family<List<MonthlyTrend>, int>((ref, year) {
  ref.watch(transactionsStreamProvider);
  return ref.watch(analyticsRepositoryProvider).monthlyTrend(year: year);
});

final monthlyCategorySpendProvider =
    FutureProvider.family<List<MonthlyCategorySpend>, int>((ref, year) {
  ref.watch(transactionsStreamProvider);
  return ref
      .watch(analyticsRepositoryProvider)
      .monthlyCategorySpend(year: year);
});

final yearSummaryProvider =
    FutureProvider.family<YearSummary, int>((ref, year) {
  ref.watch(transactionsStreamProvider);
  return ref.watch(analyticsRepositoryProvider).yearSummary(year: year);
});

final budgetVsActualProvider =
    FutureProvider.family<List<BudgetVsActual>, int>((ref, year) {
  ref.watch(transactionsStreamProvider);
  ref.watch(allBudgetsProvider);
  return ref.watch(analyticsRepositoryProvider).budgetVsActual(year: year);
});

// ── Budget ────────────────────────────────────────────────────────────────────

// Design Ref: §6 — budget providers (M4).
final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(appDatabaseProvider)),
);

/// 예산 있는 카테고리 전체. Drift watchAll() — upsert/delete 시 자동 갱신.
final allBudgetsProvider = StreamProvider<List<Budget>>(
  (ref) => ref.watch(budgetRepositoryProvider).watchAll(),
);

/// 월별 예산 현황 (지출/한도 비율). 거래·예산 변경 시 자동 재계산.
final budgetOverlayProvider =
    FutureProvider.family<List<BudgetStatus>, DateTime>((ref, month) async {
  ref.watch(transactionsStreamProvider);
  ref.watch(allBudgetsProvider);
  return ref.watch(analyticsRepositoryProvider).budgetOverlay(month: month);
});
