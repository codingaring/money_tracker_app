// Design Ref: §5.5 — TemplatePickerSheet (Input에서 호출).
// Plan SC: FR-37, FR-38. lastUsedAt desc 정렬 + 선택 시 applyTemplate.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/ui/money_format.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/ui/input_form_state.dart';

class TemplatePickerSheet extends ConsumerWidget {
  const TemplatePickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncTemplates = ref.watch(templatesByLastUsedProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  '템플릿 선택',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              asyncTemplates.when(
                loading: () => const Center(
                    child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                )),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('로드 실패: $e'),
                ),
                data: (templates) {
                  if (templates.isEmpty) {
                    return _Empty(onCreate: () => _goToManagement(context));
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final t in templates)
                        _PickerRow(
                          template: t,
                          onTap: () => _select(context, ref, t),
                        ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('새 템플릿 만들기'),
                          onPressed: () => _goToManagement(context),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _select(BuildContext context, WidgetRef ref, TxTemplate t) {
    ref.read(inputFormProvider.notifier).applyTemplate(t);
    Navigator.of(context).pop();
  }

  void _goToManagement(BuildContext context) {
    Navigator.of(context).pop();
    context.push('/settings/templates');
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.template, required this.onTap});

  final TxTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            _TypeIcon(type: template.type),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(template.name,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    final amount = template.amount == null
        ? '₩(자동)'
        : Money.formatKrw(template.amount!);
    return '${_typeLabel(template.type)} · $amount';
  }

  String _typeLabel(TxType t) => switch (t) {
        TxType.expense => '지출',
        TxType.income => '수입',
        TxType.transfer => '이체',
        TxType.valuation => '평가',
      };
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});
  final TxType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg, icon) = switch (type) {
      TxType.expense => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.primary,
          Icons.north_east_rounded
        ),
      TxType.income => (
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.tertiary,
          Icons.south_west_rounded
        ),
      TxType.transfer => (
          theme.colorScheme.surfaceContainer,
          theme.colorScheme.onSurfaceVariant,
          Icons.swap_horiz_rounded
        ),
      TxType.valuation => (
          theme.colorScheme.secondaryContainer,
          theme.colorScheme.secondary,
          Icons.trending_up_rounded
        ),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: fg),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        children: [
          Icon(Icons.bookmark_outline_rounded,
              size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('저장된 템플릿이 없습니다',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '자주 쓰는 거래를 템플릿으로 저장해두면\n입력 시간이 5초로 줄어듭니다.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('새 템플릿 만들기'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

