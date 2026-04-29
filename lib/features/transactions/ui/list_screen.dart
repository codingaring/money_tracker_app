// Design Ref: §5.4 — Transaction list grouped by date with type icons.
// M2: SearchBar + 4 chip filters integrated above the list.
// Plan SC: SC-3 — search ≤ 100ms when filter active; falls back to reactive
// stream (no extra DB calls) when filter is empty.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/ui/money_format.dart';
import '../domain/transaction.dart';
import 'filter_chips.dart';
import 'input_screen.dart';
import 'search_bar_widget.dart';

class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  static const _searchLimit = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchFilterProvider);
    final asyncAccounts = ref.watch(accountsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('거래 내역'),
        actions: [
          if (!filter.isEmpty)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_outlined),
              tooltip: '필터 초기화',
              onPressed: () =>
                  ref.read(searchFilterProvider.notifier).reset(),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: const TxSearchBar(),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: FilterChipsRow(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: asyncAccounts.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('로드 실패: $e')),
              data: (accounts) {
                final accountById = {for (final a in accounts) a.id: a};
                return filter.isEmpty
                    ? _ReactiveList(accountById: accountById)
                    : _SearchList(
                        accountById: accountById,
                        limit: _searchLimit,
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactiveList extends ConsumerWidget {
  const _ReactiveList({required this.accountById});

  final Map<int, Account> accountById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTxs = ref.watch(transactionsStreamProvider);
    return asyncTxs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('로드 실패: $e')),
      data: (txs) {
        if (txs.isEmpty) return const _EmptyState();
        return _GroupedList(txs: txs, accountById: accountById);
      },
    );
  }
}

class _SearchList extends ConsumerWidget {
  const _SearchList({required this.accountById, required this.limit});

  final Map<int, Account> accountById;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncResults = ref.watch(searchResultsProvider);
    return asyncResults.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('검색 실패: $e')),
      data: (txs) {
        if (txs.isEmpty) return const _NoMatches();
        return Column(
          children: [
            _ResultsHeader(count: txs.length, limit: limit),
            Expanded(
              child: _GroupedList(txs: txs, accountById: accountById),
            ),
          ],
        );
      },
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.count, required this.limit});

  final int count;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saturated = count >= limit;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Text(
            '결과 $count건${saturated ? ' (최대)' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          if (saturated) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '필터를 더 좁혀보세요',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.txs, required this.accountById});

  final List<TxRow> txs;
  final Map<int, Account> accountById;

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate(txs);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: groups.length,
      itemBuilder: (ctx, i) {
        final entry = groups[i];
        return _DateGroup(
          date: entry.date,
          transactions: entry.txs,
          accountById: accountById,
        );
      },
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              '조건에 맞는 거래가 없습니다',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 80, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('거래가 없습니다',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 8),
            Text('아래 [입력] 탭에서 첫 거래를 추가하세요.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

class _DateGroup extends ConsumerWidget {
  const _DateGroup({
    required this.date,
    required this.transactions,
    required this.accountById,
  });

  final DateTime date;
  final List<TxRow> transactions;
  final Map<int, Account> accountById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          alignment: Alignment.centerLeft,
          child: Text(
            DateLabels.dateWithDow(date),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...transactions.map(
          (tx) => _TxTile(
            tx: tx,
            accountById: accountById,
            onDelete: () => _confirmDelete(context, ref, tx),
            onEdit: () => _openEdit(context, tx),
          ),
        ),
      ],
    );
  }

  Future<void> _openEdit(BuildContext context, TxRow tx) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InputScreen(existing: tx)),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, TxRow tx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('거래 삭제'),
        content: Text(
            '${Money.formatKrw(tx.amount)} ${tx.type.name} 거래를 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(transactionRepositoryProvider).delete(tx.localId);
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({
    required this.tx,
    required this.accountById,
    required this.onDelete,
    required this.onEdit,
  });

  final TxRow tx;
  final Map<int, Account> accountById;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fromName = tx.fromAccountId == null
        ? null
        : accountById[tx.fromAccountId]?.name;
    final toName =
        tx.toAccountId == null ? null : accountById[tx.toAccountId]?.name;

    final unsynced = tx.syncedAt == null;

    return Dismissible(
      key: ValueKey('tx-${tx.localId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // we trigger reactive rebuild via Repository
      },
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      child: ListTile(
        onTap: onEdit,
        leading: _TypeIcon(type: tx.type),
        title: Row(
          children: [
            Expanded(
              child: Text(
                tx.memo?.isNotEmpty == true ? tx.memo! : tx.type.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _amountFor(tx),
              style: theme.textTheme.titleMedium?.copyWith(
                color: _amountColor(tx, theme),
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            if (fromName != null && toName != null)
              Text('$fromName → $toName',
                  style: theme.textTheme.bodySmall),
            if (fromName != null && toName == null)
              Text(fromName, style: theme.textTheme.bodySmall),
            if (fromName == null && toName != null)
              Text('→ $toName', style: theme.textTheme.bodySmall),
            if (tx.memo != null && tx.memo!.isNotEmpty) ...[
              Text(' · ', style: theme.textTheme.bodySmall),
              Expanded(
                child: Text(tx.memo!,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
            if (unsynced)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Tooltip(
                  message: '동기화 대기',
                  child: Icon(Icons.cloud_off,
                      size: 14, color: theme.colorScheme.outline),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _amountFor(TxRow tx) {
    switch (tx.type) {
      case TxType.expense:
        return '-${Money.format(tx.amount)}';
      case TxType.income:
        return '+${Money.format(tx.amount)}';
      case TxType.transfer:
        return Money.format(tx.amount);
      case TxType.valuation:
        return Money.format(tx.amount);
    }
  }

  Color? _amountColor(TxRow tx, ThemeData theme) {
    return switch (tx.type) {
      TxType.expense => theme.colorScheme.primary,
      TxType.income => theme.colorScheme.tertiary,
      TxType.transfer => theme.colorScheme.onSurfaceVariant,
      TxType.valuation => theme.colorScheme.secondary,
    };
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});

  final TxType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = switch (type) {
      TxType.expense => theme.colorScheme.primaryContainer,
      TxType.income => theme.colorScheme.tertiaryContainer,
      TxType.transfer => theme.colorScheme.surfaceContainer,
      TxType.valuation => theme.colorScheme.secondaryContainer,
    };
    final fg = switch (type) {
      TxType.expense => theme.colorScheme.primary,
      TxType.income => theme.colorScheme.tertiary,
      TxType.transfer => theme.colorScheme.onSurfaceVariant,
      TxType.valuation => theme.colorScheme.secondary,
    };
    return CircleAvatar(
      radius: 18,
      backgroundColor: bg,
      child: Icon(
        switch (type) {
          TxType.expense => Icons.north_east_rounded,
          TxType.income => Icons.south_west_rounded,
          TxType.transfer => Icons.swap_horiz_rounded,
          TxType.valuation => Icons.trending_up_rounded,
        },
        size: 18,
        color: fg,
      ),
    );
  }
}

extension on TxType {
  String get label => switch (this) {
        TxType.expense => '지출',
        TxType.income => '수입',
        TxType.transfer => '이체',
        TxType.valuation => '평가',
      };
}

class _Group {
  _Group(this.date, this.txs);
  final DateTime date;
  final List<TxRow> txs;
}

List<_Group> _groupByDate(List<TxRow> txs) {
  final map = <String, _Group>{};
  for (final tx in txs) {
    final key = DateLabels.ymd(tx.occurredAt);
    map.putIfAbsent(
      key,
      () => _Group(
        DateTime(tx.occurredAt.year, tx.occurredAt.month, tx.occurredAt.day),
        [],
      ),
    );
    map[key]!.txs.add(tx);
  }
  final list = map.values.toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return list;
}
