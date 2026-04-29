// Design Ref: §5.2 — 4-type dynamic input form (FR-16) + FR-17 카드 안내.
// Plan SC: 5초 입력 — auto-focus amount field on entry.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../../../core/ui/money_format.dart';
import '../../accounts/domain/account.dart';
import '../../categories/domain/category.dart';
import '../../categories/ui/category_picker.dart';
import '../../templates/ui/template_picker_sheet.dart';
import '../domain/transaction.dart';
import 'input_form_state.dart';

class InputScreen extends ConsumerStatefulWidget {
  const InputScreen({super.key, this.existing});

  /// When non-null the screen runs in **edit mode**: form is pre-populated
  /// from this row and submit calls `Repository.update` (FR-05).
  final TxRow? existing;

  @override
  ConsumerState<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends ConsumerState<InputScreen> {
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  final _amountFocus = FocusNode();
  bool _submitting = false;
  String? _errorMessage;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isEdit) {
        _populateFromExisting();
      } else {
        _amountFocus.requestFocus();
      }
    });
    if (!_isEdit) {
      final initial = ref.read(inputFormProvider);
      _memoController.text = initial.memo;
    }
  }

  void _populateFromExisting() {
    final tx = widget.existing!;
    final notifier = ref.read(inputFormProvider.notifier);
    notifier.reset();
    // setType clears account/category — call FIRST, then populate.
    notifier.setType(tx.type);
    notifier.setAmount(tx.amount);
    notifier.setFromAccount(tx.fromAccountId);
    notifier.setToAccount(tx.toAccountId);
    notifier.setCategory(tx.categoryId);
    notifier.setMemo(tx.memo ?? '');
    notifier.setOccurredAt(tx.occurredAt);
    _amountController.text = Money.format(tx.amount);
    _memoController.text = tx.memo ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _openPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const TemplatePickerSheet(),
    );
    if (!mounted) return;
    // Sync controllers from form state — applyTemplate changed amount/memo.
    final form = ref.read(inputFormProvider);
    _amountController.text = form.amount > 0 ? Money.format(form.amount) : '';
    _memoController.text = form.memo;
  }

  Future<void> _submit() async {
    final form = ref.read(inputFormProvider);
    final result = form.toDraft();
    if (result.draft == null) {
      setState(() => _errorMessage = result.error);
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(transactionRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.existing!, result.draft!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('수정됨'), duration: Duration(seconds: 1)),
        );
        Navigator.of(context).maybePop();
        return;
      }
      await repo.add(result.draft!);
      // Plan SC: FR-38 — markUsed only on successful save (not cancel/fail).
      final templateId = form.appliedTemplateId;
      if (templateId != null) {
        await ref.read(templateRepositoryProvider).markUsed(templateId);
      }
      if (!mounted) return;
      // Reset form, keep type for fast repeated entry.
      final keepType = form.type;
      ref.read(inputFormProvider.notifier).reset();
      ref.read(inputFormProvider.notifier).setType(keepType);
      _amountController.clear();
      _memoController.clear();
      _amountFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('저장됨'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(inputFormProvider);
    final notifier = ref.read(inputFormProvider.notifier);
    final asyncAccounts = ref.watch(accountsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(_isEdit ? '거래 수정' : '거래 추가'),
      ),
      body: asyncAccounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('계좌 로드 실패: $e')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const _NoAccountsHint();
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!_isEdit) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.bookmark_border_rounded, size: 18),
                    label: const Text('템플릿에서'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: () => _openPicker(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _TypeSelector(
                value: form.type,
                onChanged: (v) => notifier.setType(v),
              ),
              const SizedBox(height: 20),
              _AmountField(
                controller: _amountController,
                focusNode: _amountFocus,
                onChanged: (v) => notifier.setAmount(v),
              ),
              const SizedBox(height: 16),
              ..._fieldsForType(form, notifier, accounts),
              const SizedBox(height: 12),
              TextField(
                controller: _memoController,
                decoration: const InputDecoration(
                  labelText: '메모 (선택)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 200,
                onChanged: notifier.setMemo,
              ),
              _DateRow(
                date: form.occurredAt,
                onChanged: notifier.setOccurredAt,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _isEdit ? '수정 저장' : '저장',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _fieldsForType(
    InputFormState form,
    InputFormNotifier notifier,
    List<Account> accounts,
  ) {
    final widgets = <Widget>[];

    if (form.type == TxType.expense || form.type == TxType.transfer) {
      widgets.add(_AccountField(
        label: form.type == TxType.transfer ? '보내는 계좌' : '계좌',
        accounts: accounts,
        value: form.fromAccountId,
        excludedId: form.type == TxType.transfer ? form.toAccountId : null,
        onChanged: notifier.setFromAccount,
      ));
      // Card 발생주의 안내 (FR-17)
      final from = accounts.where((a) => a.id == form.fromAccountId).firstOrNull;
      if (from?.type == AccountType.creditCard && form.type == TxType.expense) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(_CardHint());
      }
      widgets.add(const SizedBox(height: 12));
    }

    if (form.type == TxType.income ||
        form.type == TxType.transfer ||
        form.type == TxType.valuation) {
      widgets.add(_AccountField(
        label: form.type == TxType.transfer ? '받는 계좌' : '계좌',
        accounts: accounts,
        value: form.toAccountId,
        excludedId: form.type == TxType.transfer ? form.fromAccountId : null,
        onChanged: notifier.setToAccount,
      ));
      // Plan SC: FR-30 — confirm transfer-to-credit_card semantics so users
      // don't accidentally log a card *purchase* as a transfer.
      if (form.type == TxType.transfer) {
        final to =
            accounts.where((a) => a.id == form.toAccountId).firstOrNull;
        if (to?.type == AccountType.creditCard) {
          widgets.add(const SizedBox(height: 8));
          widgets.add(_TransferToCardHint());
        }
      }
      widgets.add(const SizedBox(height: 12));
    }

    if (form.type == TxType.expense || form.type == TxType.income) {
      widgets.add(CategoryPicker(
        kind: form.type == TxType.expense
            ? CategoryKind.expense
            : CategoryKind.income,
        selectedId: form.categoryId,
        onChanged: notifier.setCategory,
      ));
      widgets.add(const SizedBox(height: 12));
    }

    return widgets;
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.value, required this.onChanged});

  final TxType value;
  final ValueChanged<TxType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TxType>(
      segments: const [
        ButtonSegment(value: TxType.expense, label: Text('지출')),
        ButtonSegment(value: TxType.income, label: Text('수입')),
        ButtonSegment(value: TxType.transfer, label: Text('이체')),
        ButtonSegment(value: TxType.valuation, label: Text('평가')),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        prefixText: '₩  ',
        prefixStyle: theme.textTheme.headlineMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
        hintText: '0',
        hintStyle: theme.textTheme.headlineMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [_ThousandsFormatter()],
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      onChanged: (s) {
        final v = int.tryParse(s.replaceAll(',', '')) ?? 0;
        onChanged(v);
      },
    );
  }
}

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final clean = newValue.text.replaceAll(',', '');
    final parsed = int.tryParse(clean);
    if (parsed == null) return oldValue;
    final formatted = Money.format(parsed);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _AccountField extends StatelessWidget {
  const _AccountField({
    required this.label,
    required this.accounts,
    required this.value,
    required this.onChanged,
    this.excludedId,
  });

  final String label;
  final List<Account> accounts;
  final int? value;
  final int? excludedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final filtered = accounts.where((a) => a.id != excludedId).toList();
    return DropdownButtonFormField<int>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      initialValue: value,
      items: filtered
          .map((a) => DropdownMenuItem(
                value: a.id,
                child: Text('${a.name}  ·  ${_typeLabel(a.type)}'),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  String _typeLabel(AccountType t) => switch (t) {
        AccountType.cash => '현금',
        AccountType.investment => '투자',
        AccountType.savings => '저축',
        AccountType.realEstate => '부동산',
        AccountType.creditCard => '신용카드',
        AccountType.loan => '대출',
      };
}

// _CategoryField는 M3에서 CategoryPicker로 대체됨 (categories-ui scope).

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onChanged});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 18),
          const SizedBox(width: 8),
          Text(DateLabels.dateWithDow(date)),
          const Spacer(),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) onChanged(picked);
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }
}

class _CardHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.credit_card,
              size: 18, color: theme.colorScheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '카드값 출금이 아니라 사용 내역인가요? '
              '카드값 출금은 [이체]로 입력하세요.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferToCardHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.payment,
              size: 18, color: theme.colorScheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '카드값 결제가 맞나요? '
              '결제 시 카드 잔액(부채)이 0에 가까워지고, 통장 잔액이 줄어듭니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoAccountsHint extends StatelessWidget {
  const _NoAccountsHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 80, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('계좌가 없습니다',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('[계좌] 탭에서 통장/카드/투자 계좌를 먼저 등록하세요.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
