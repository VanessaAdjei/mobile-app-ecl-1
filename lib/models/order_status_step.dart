class OrderStatusStep {
  const OrderStatusStep({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.isCurrent,
    this.occurredAt,
  });

  final String id;
  final String title;
  final bool isCompleted;
  final bool isCurrent;

  /// When this step was reached (API or locally recorded).
  final DateTime? occurredAt;
}
