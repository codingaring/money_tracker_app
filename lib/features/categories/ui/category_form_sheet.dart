// Design Ref: §5.10 — CategoryFormSheet (생성/수정 BottomSheet).
// Plan SC: FR-50. parent dropdown은 같은 kind의 대분류만 (자기 자신 제외).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/db/app_database.dart';
import '../domain/category.dart';

class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({super.key, this.existing, this.defaultKind});

  /// Edit mode when non-null.
  final Category? existing;

  /// 새 카테고리의 기본 kind (CategoriesScreen의 현재 탭에서 전달).
  final CategoryKind? defaultKind;

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  late final TextEditingController _nameController;
  late CategoryKind _kind;
  int? _parentId;
  bool _isFixed = false;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _kind = e?.kind ?? widget.defaultKind ?? CategoryKind.expense;
    _parentId = e?.parentCategoryId;
    _isFixed = e?.isFixed ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '이름을 입력하세요');
      return;
    }
    final repo = ref.read(categoryRepositoryProvider);
    // unique 검증 (자기 자신 제외)
    final existing = await repo.findByName(name);
    if (existing != null && existing.id != widget.existing?.id) {
      if (mounted) setState(() => _error = '같은 이름의 카테고리가 이미 있습니다');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await repo.updateMeta(
          widget.existing!.id,
          name: name,
          isFixed: _isFixed,
        );
        // parent 변경은 setParent로 별도 처리 (순환 검증 포함)
        if (_parentId != widget.existing!.parentCategoryId) {
          await repo.setParent(widget.existing!.id, _parentId);
        }
      } else {
        await repo.create(
          name: name,
          kind: _kind,
          isFixed: _isFixed,
          parentCategoryId: _parentId,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;
    // parent 후보: 같은 kind의 대분류만 (자기 자신 제외).
    final allAsync = ref.watch(categoriesByKindProvider(_kind));

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text(_isEdit ? '카테고리 수정' : '카테고리 추가',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '이름',
                hintText: '예: 점심값, 카페',
              ),
              maxLength: 40,
            ),
            const SizedBox(height: 12),
            // kind 선택은 신규 생성 때만 (수정은 기존 kind 고정).
            if (!_isEdit)
              SegmentedButton<CategoryKind>(
                segments: const [
                  ButtonSegment(value: CategoryKind.expense, label: Text('지출')),
                  ButtonSegment(value: CategoryKind.income, label: Text('수입')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() {
                  _kind = s.first;
                  _parentId = null; // kind 변경 시 stale parent clear
                }),
              ),
            if (!_isEdit) const SizedBox(height: 12),
            // parent dropdown (대분류만, 자기 자신 제외)
            allAsync.maybeWhen(
              data: (all) => _ParentDropdown(
                allInKind: all,
                selfId: widget.existing?.id,
                value: _parentId,
                onChanged: (v) => setState(() => _parentId = v),
              ),
              orElse: () => const SizedBox(
                height: 56,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            if (_kind == CategoryKind.expense) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('고정비'),
                subtitle: const Text('월세/통신비 등 매월 비슷한 금액'),
                value: _isFixed,
                onChanged: (v) => setState(() => _isFixed = v),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _save,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? '저장' : '추가'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentDropdown extends StatelessWidget {
  const _ParentDropdown({
    required this.allInKind,
    required this.selfId,
    required this.value,
    required this.onChanged,
  });

  final List<Category> allInKind;
  final int? selfId;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    // 부모 후보 = parent NULL인 카테고리(=대분류) 중 자기 자신 제외
    final candidates = allInKind
        .where((c) => c.parentCategoryId == null && c.id != selfId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: '부모 카테고리 (선택)',
        helperText: '비우면 대분류로 등록 — 다른 카테고리의 부모가 될 수 있음',
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          hint: const Text('— 없음 (대분류) —'),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('— 없음 (대분류) —'),
            ),
            for (final c in candidates)
              DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
