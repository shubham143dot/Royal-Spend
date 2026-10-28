class Budget {
  final String id;
  final double monthlyLimit;
  final int month; // 1-12
  final int year;
  final double warningThreshold; // e.g. 0.8 for 80%

  const Budget({
    required this.id,
    required this.monthlyLimit,
    required this.month,
    required this.year,
    this.warningThreshold = 0.8,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'monthly_limit': monthlyLimit,
      'month': month,
      'year': year,
      'warning_threshold': warningThreshold,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      monthlyLimit: (map['monthly_limit'] as num).toDouble(),
      month: map['month'] as int,
      year: map['year'] as int,
      warningThreshold: (map['warning_threshold'] as num).toDouble(),
    );
  }

  Budget copyWith({
    String? id,
    double? monthlyLimit,
    int? month,
    int? year,
    double? warningThreshold,
  }) {
    return Budget(
      id: id ?? this.id,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      month: month ?? this.month,
      year: year ?? this.year,
      warningThreshold: warningThreshold ?? this.warningThreshold,
    );
  }
}
