// Design Ref: §5.1 — DailyCalendar (월 그리드 + heatmap + 합계).
// Plan SC: FR-40, FR-42. 7×6 그리드, 일요일 시작, expense 합계 + heatmap.

import 'package:flutter/material.dart';

class DailyCalendar extends StatelessWidget {
  const DailyCalendar({
    super.key,
    required this.month,
    required this.dailyMap,
    required this.onDayTap,
  });

  /// 표시할 달 (1일이면 충분, 다른 day여도 무관 — month/year만 사용).
  final DateTime month;

  /// midnight DateTime → expense 합계 (KRW).
  final Map<DateTime, int> dailyMap;

  /// 일자 셀 탭 콜백. midnight DateTime을 전달.
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstOfMonth = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // weekday: 일=7, 월=1 (Dart 표준). 캘린더는 일요일 시작.
    // Sunday-first: weekday(Sun)=7 → 0번째 칸. weekday(Sat)=6 → 6번째 칸.
    final firstWeekday = firstOfMonth.weekday % 7;

    final maxAmount = dailyMap.values.fold<int>(0, (a, b) => a > b ? a : b);
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // 6 weeks × 7 days = 42 cells (sufficient for any month).
    const totalCells = 42;
    final cells = <Widget>[];
    for (var i = 0; i < totalCells; i++) {
      final dayNum = i - firstWeekday + 1;
      if (dayNum < 1 || dayNum > daysInMonth) {
        cells.add(const _EmptyCell());
        continue;
      }
      final day = DateTime(month.year, month.month, dayNum);
      final amount = dailyMap[day] ?? 0;
      cells.add(_DayCell(
        dayNum: dayNum,
        amount: amount,
        isToday: day == today,
        heatAlpha: _heatmapAlpha(amount, maxAmount),
        onTap: () => onDayTap(day),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 요일 헤더
        Row(
          children: [
            for (final w in const ['일', '월', '화', '수', '목', '금', '토'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: w == '일'
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // 그리드
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 0.92,
          children: cells,
        ),
        if (dailyMap.isEmpty) ...[
          const SizedBox(height: 16),
          Center(
            child: Text(
              '이 달에는 지출이 없습니다',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Design §13 — `(amount/max).clamp(0.05, 0.7)`. 0인 셀은 투명.
  double _heatmapAlpha(int amount, int maxAmount) {
    if (amount == 0 || maxAmount == 0) return 0;
    final ratio = amount / maxAmount;
    return (0.05 + ratio * 0.65).clamp(0.05, 0.7);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayNum,
    required this.amount,
    required this.isToday,
    required this.heatAlpha,
    required this.onTap,
  });

  final int dayNum;
  final int amount;
  final bool isToday;
  final double heatAlpha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAmount = amount > 0;
    final bg = heatAlpha > 0
        ? theme.colorScheme.primary.withValues(alpha: heatAlpha)
        : Colors.transparent;
    // hot pink heatmap에서 텍스트는 어두운 톤(onSurface)이 가독성 좋음.
    final amountColor = heatAlpha > 0.4
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.primary;

    return InkWell(
      onTap: hasAmount ? onTap : onTap, // 0원 날짜도 탭 허용 (그날 거래 0건 확인용)
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: isToday
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$dayNum',
              style: theme.textTheme.labelMedium?.copyWith(
                color: heatAlpha > 0.4
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (hasAmount)
              Align(
                alignment: Alignment.bottomRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _shortAmount(amount),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 천 단위 줄임. 1,200 → 1k / 12,500 → 12k / 1,250,000 → 1.2M.
  String _shortAmount(int amount) {
    if (amount < 1000) return '$amount';
    if (amount < 1000000) return '${(amount / 1000).round()}k';
    return '${(amount / 1000000).toStringAsFixed(1)}M';
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

