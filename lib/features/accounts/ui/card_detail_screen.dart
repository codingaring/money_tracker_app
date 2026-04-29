// Design Ref: §5.3 — CardDetailScreen (계좌 탭 drill-down).
// Plan SC: SC-1 (카드 결제 예정 D-day + 예상 금액 정확).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/ui/money_format.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/card_detail_metrics.dart';

class CardDetailScreen extends ConsumerWidget {
  const CardDetailScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMetrics = ref.watch(cardDetailProvider(accountId));
    return Scaffold(
      appBar: AppBar(
        title: asyncMetrics.maybeWhen(
          data: (m) => Text(m.account.name),
          orElse: () => const Text('카드 상세'),
        ),
      ),
      body: asyncMetrics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBox(message: '$e'),
        data: (m) => _CardDetailBody(metrics: m),
      ),
    );
  }
}

class _CardDetailBody extends StatelessWidget {
  const _CardDetailBody({required this.metrics});

  final CardDetailMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        _NextDuePanel(metrics: metrics),
        const SizedBox(height: 16),
        _ThisMonthPanel(metrics: metrics),
        const SizedBox(height: 24),
        const _SectionHeader(title: '최근 사용'),
        const SizedBox(height: 4),
        if (metrics.recentCharges.isEmpty)
          const _EmptyTransactions()
        else
          ...metrics.recentCharges
              .map((tx) => _RecentTile(tx: tx, account: metrics.account)),
      ],
    );
  }
}

class _NextDuePanel extends StatelessWidget {
  const _NextDuePanel({required this.metrics});

  final CardDetailMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card_rounded,
                  color: theme.colorScheme.onPrimary, size: 20),
              const SizedBox(width: 8),
              Text('다음 결제',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  )),
              const Spacer(),
              if (metrics.hasDueDay) _DayPill(daysUntil: metrics.daysUntilDue),
            ],
          ),
          const SizedBox(height: 16),
          if (metrics.hasDueDay) ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Money.formatKrw(metrics.expectedPayment),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _dueDateLabel(metrics.nextDueDate!),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
              ),
            ),
          ] else ...[
            Text('결제일 미설정',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                )),
            const SizedBox(height: 8),
            Text(
              '계좌 수정에서 결제일을 추가하면 D-day가 표시됩니다.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _dueDateLabel(DateTime due) =>
      '${due.month.toString().padLeft(2, '0')}월 ${due.day.toString().padLeft(2, '0')}일 결제 예정';
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.daysUntil});

  final int daysUntil;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = daysUntil == 0
        ? 'D-DAY'
        : daysUntil == 1
            ? 'D-1'
            : 'D-$daysUntil';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.onPrimary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ThisMonthPanel extends StatelessWidget {
  const _ThisMonthPanel({required this.metrics});

  final CardDetailMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expected = metrics.expectedPayment;
    final used = metrics.currentMonthCharges;
    final ratio = expected > 0 ? (used / expected).clamp(0.0, 1.0) : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이번 달 사용',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Money.formatKrw(used),
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainer,
                valueColor:
                    AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              expected > 0
                  ? '예상 결제액 대비 ${(ratio * 100).round()}%'
                  : '예상 결제액 0 — 잔액 음수가 될 때 비율이 표시됩니다.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.tx, required this.account});

  final TxRow tx;
  final Account account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOutgoing = tx.fromAccountId == account.id;
    final signed = isOutgoing ? -tx.amount : tx.amount;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        DateLabels.dateWithDow(tx.occurredAt),
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.outline),
      ),
      subtitle: Text(
        tx.memo?.isNotEmpty == true ? tx.memo! : _typeLabel(tx.type),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        Money.formatSigned(signed),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: signed < 0 ? theme.colorScheme.error : null,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  String _typeLabel(TxType t) => switch (t) {
        TxType.expense => '지출',
        TxType.income => '수입',
        TxType.transfer => '이체',
        TxType.valuation => '평가',
      };
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 8),
          Text('이 카드의 사용 내역이 없습니다',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text('카드 상세 로드 실패\n$message',
            textAlign: TextAlign.center),
      ),
    );
  }
}
