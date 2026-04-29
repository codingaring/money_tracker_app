// Design Ref: §4.1 — CategorySegment value object for donut chart.
// Plan SC: SC-2 (월별 카테고리 도너츠).

class CategorySegment {
  const CategorySegment({
    required this.categoryId,
    required this.categoryName,
    required this.isFixed,
    required this.totalAmount,
  });

  final int categoryId;
  final String categoryName;
  final bool isFixed;

  /// expense 합계 (KRW, positive). Always > 0 by construction in repository.
  final int totalAmount;
}
