class OrderStatusStep {
  const OrderStatusStep({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.isCurrent,
  });

  final String id;
  final String title;
  final bool isCompleted;
  final bool isCurrent;
}
