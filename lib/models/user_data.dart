class UserData {
  final double balance;
  final double cushion;
  final double cushionGoal;
  final double debts;
  final double savings;
  final double expenses;
  final double income;
  final Map<String, dynamic> extra;

  UserData({
    this.balance = 0,
    this.cushion = 0,
    this.cushionGoal = 0,
    this.debts = 0,
    this.savings = 0,
    this.expenses = 0,
    this.income = 0,
    this.extra = const {},
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      balance: _toDouble(json['balance']),
      cushion: _toDouble(json['cushion']),
      cushionGoal: _toDouble(json['cushion_goal']),
      debts: _toDouble(json['debts']),
      savings: _toDouble(json['savings']),
      expenses: _toDouble(json['expenses']),
      income: _toDouble(json['income']),
      extra: Map<String, dynamic>.from(json),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  double get remainingToGoal => cushionGoal - cushion;
  double get netWorth => balance + cushion - debts;
}

class Transaction {
  final String id;
  final String type; // income, expense, debt
  final double amount;
  final String category;
  final String description;
  final String date;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'expense',
      amount: _toDouble(json['amount']),
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
