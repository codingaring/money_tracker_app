// Design Ref: §5.4 + §5.5 — Accounts CRUD list + M2 트리 들여쓰기.
// Plan SC: FR-01 (Account CRUD) + FR-19 (credit_card drill-down) +
//          FR-28 (parent-child tree).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/ui/money_format.dart';
import '../domain/account.dart';
import 'account_form_sheet.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAccounts = ref.watch(accountsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('계좌')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'accounts-add-fab',
        icon: const Icon(Icons.add),
        label: const Text('계좌 추가'),
        onPressed: () => _openCreate(context, ref),
      ),
      body: asyncAccounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('로드 실패: $e')),
        data: (accounts) {
          if (accounts.isEmpty) return const _Empty();
          final groups = _bucketize(accounts);
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final entry in groups.entries) ...[
                _BucketHeader(title: entry.key),
                ..._renderBucket(context, ref, entry.value, accounts),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AccountFormSheet(),
    );
  }

  Future<void> _openEdit(
      BuildContext context, WidgetRef ref, Account a) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AccountFormSheet(existing: a),
    );
  }

  /// Renders a bucket as a tree: bucket-root accounts first, then their
  /// children indented underneath. Children whose parent is in a *different*
  /// bucket fall back to flat rendering inside the current bucket.
  Iterable<Widget> _renderBucket(
    BuildContext context,
    WidgetRef ref,
    List<Account> bucketAccounts,
    List<Account> allAccounts,
  ) {
    final widgets = <Widget>[];
    final inBucket = {for (final a in bucketAccounts) a.id};
    final orphans =
        bucketAccounts.where((a) => !inBucket.contains(a.parentAccountId));
    final byParent = <int, List<Account>>{};
    for (final a in allAccounts) {
      final pid = a.parentAccountId;
      if (pid != null) {
        byParent.putIfAbsent(pid, () => <Account>[]).add(a);
      }
    }

    for (final root in orphans) {
      widgets.add(_AccountTile(
        account: root,
        depth: 0,
        onTap: () => _onTapAccount(context, ref, root),
      ));
      // 1-level deep is enough for M2 (card → bank). Recurse defensively
      // so deeper tree later just works.
      _appendChildren(
        widgets: widgets,
        parentId: root.id,
        byParent: byParent,
        depth: 1,
        onTap: (a) => _onTapAccount(context, ref, a),
      );
    }
    return widgets;
  }

  void _appendChildren({
    required List<Widget> widgets,
    required int parentId,
    required Map<int, List<Account>> byParent,
    required int depth,
    required void Function(Account) onTap,
  }) {
    final children = byParent[parentId];
    if (children == null) return;
    for (final c in children) {
      widgets.add(_AccountTile(
        account: c,
        depth: depth,
        onTap: () => onTap(c),
      ));
      _appendChildren(
        widgets: widgets,
        parentId: c.id,
        byParent: byParent,
        depth: depth + 1,
        onTap: onTap,
      );
    }
  }

  void _onTapAccount(BuildContext context, WidgetRef ref, Account a) {
    if (a.type == AccountType.creditCard) {
      // Plan SC: FR-19 — drill-down to CardDetailScreen.
      context.push('/accounts/card/${a.id}');
    } else {
      _openEdit(context, ref, a);
    }
  }
}

const Map<AccountType, String> _bucketLabels = {
  AccountType.cash: '현금성',
  AccountType.investment: '투자',
  AccountType.savings: '저축',
  AccountType.realEstate: '부동산',
  AccountType.creditCard: '부채 — 신용카드',
  AccountType.loan: '부채 — 대출',
};

Map<String, List<Account>> _bucketize(List<Account> accounts) {
  // Render order matches the dictionary above (cash → investment → ... → loan).
  final result = <String, List<Account>>{
    for (final label in _bucketLabels.values) label: <Account>[],
  };
  for (final a in accounts) {
    result[_bucketLabels[a.type]!]!.add(a);
  }
  result.removeWhere((_, list) => list.isEmpty);
  return result;
}

class _BucketHeader extends StatelessWidget {
  const _BucketHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.depth,
    required this.onTap,
  });

  final Account account;
  final int depth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final negative = account.balance < 0;
    final isCard = account.type == AccountType.creditCard;
    final palette = _palette(theme.colorScheme, account.type);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(20 + (depth * 20).toDouble(), 12, 20, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.bg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(_iconFor(account.type),
                  size: 20, color: palette.fg),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: account.isActive
                          ? null
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (account.note?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        account.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              Money.formatKrw(account.balance),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: negative ? theme.colorScheme.error : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (isCard) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.outline),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(AccountType t) => switch (t) {
        AccountType.cash => Icons.account_balance_rounded,
        AccountType.investment => Icons.trending_up_rounded,
        AccountType.savings => Icons.savings_rounded,
        AccountType.realEstate => Icons.home_work_rounded,
        AccountType.creditCard => Icons.credit_card_rounded,
        AccountType.loan => Icons.assignment_rounded,
      };

  ({Color bg, Color fg}) _palette(ColorScheme cs, AccountType t) {
    return switch (t) {
      AccountType.cash =>
        (bg: cs.tertiaryContainer, fg: cs.tertiary),
      AccountType.investment =>
        (bg: cs.primaryContainer, fg: cs.primary),
      AccountType.savings =>
        (bg: cs.tertiaryContainer, fg: cs.tertiary),
      AccountType.realEstate =>
        (bg: cs.surfaceContainerHigh, fg: cs.onSurface),
      AccountType.creditCard =>
        (bg: cs.primaryContainer, fg: cs.primary),
      AccountType.loan =>
        (bg: cs.errorContainer, fg: cs.error),
    };
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_outlined,
                size: 80, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('등록된 계좌가 없습니다',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('우측 하단 [+] 버튼으로 계좌를 추가하세요.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
