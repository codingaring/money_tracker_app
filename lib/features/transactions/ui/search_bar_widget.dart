// Design Ref: §5.4 — SearchBar (debounce 250ms, memo only).
// Plan SC: SC-3 (검색 응답 ≤ 100ms — debounce reduces DAO calls during typing).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';

class TxSearchBar extends ConsumerStatefulWidget {
  const TxSearchBar({super.key});

  @override
  ConsumerState<TxSearchBar> createState() => _TxSearchBarState();
}

class _TxSearchBarState extends ConsumerState<TxSearchBar> {
  static const _debounce = Duration(milliseconds: 250);
  late final TextEditingController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(searchFilterProvider).keyword,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (!mounted) return;
      ref.read(searchFilterProvider.notifier).setKeyword(value);
    });
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    ref.read(searchFilterProvider.notifier).setKeyword('');
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: '메모 검색',
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _clear,
                tooltip: '검색어 지우기',
              )
            : null,
      ),
    );
  }
}
