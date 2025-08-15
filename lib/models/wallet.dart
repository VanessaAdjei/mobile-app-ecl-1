// models/wallet.dart
// models/wallet.dart
// models/wallet.dart
class Wallet {
  final String id;
  final String userId;
  final double balance;
  final String currency;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WalletTransaction> transactions;

  Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.transactions = const [],
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      balance: (json['balance'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'GHS',
      status: json['status'] ?? 'active',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((t) => WalletTransaction.fromJson(t))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'balance': balance,
      'currency': currency,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };
  }

  Wallet copyWith({
    String? id,
    String? userId,
    double? balance,
    String? currency,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<WalletTransaction>? transactions,
  }) {
    return Wallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      transactions: transactions ?? this.transactions,
    );
  }
}

class WalletTransaction {
  final String id;
  final String walletId;
  final String
      type; // 'credit', 'debit', 'refund', 'cashback', 'bonus', 'return'
  final double amount;
  final String description;
  final String reference;
  final String status; // 'pending', 'completed', 'failed'
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  WalletTransaction({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.description,
    required this.reference,
    required this.status,
    required this.createdAt,
    this.metadata,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id']?.toString() ?? '',
      walletId: json['wallet_id']?.toString() ?? '',
      type: json['type'] ?? 'debit',
      amount: (json['amount'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      reference: json['reference'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wallet_id': walletId,
      'type': type,
      'amount': amount,
      'description': description,
      'reference': reference,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  bool get isCredit =>
      type == 'credit' ||
      type == 'refund' ||
      type == 'cashback' ||
      type == 'bonus' ||
      type == 'return';
  bool get isDebit => type == 'debit';
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';

  // Specific transaction type getters
  bool get isRefund => type == 'refund';
  bool get isCashback => type == 'cashback';
  bool get isReturn => type == 'return';
  bool get isBonus => type == 'bonus';
}
