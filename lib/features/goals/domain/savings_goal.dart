enum SavingsGoalStatus { active, paused, completed }

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetCents,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.deadline,
    this.completedAt,
  });

  final String id;
  final String name;
  final int targetCents;
  final DateTime? deadline;
  final SavingsGoalStatus status;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get target => targetCents / 100;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name.trim(),
      'targetCents': targetCents,
      'deadline': deadline?.toIso8601String(),
      'status': status.name,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SavingsGoal.fromMap(Map<String, Object?> map) {
    final DateTime now = DateTime.now();
    return SavingsGoal(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString().trim() ?? '',
      targetCents: (map['targetCents'] as num?)?.toInt() ?? 0,
      deadline: DateTime.tryParse(map['deadline']?.toString() ?? ''),
      status: SavingsGoalStatus.values.firstWhere(
        (SavingsGoalStatus value) => value.name == map['status'],
        orElse: () => SavingsGoalStatus.active,
      ),
      completedAt: DateTime.tryParse(map['completedAt']?.toString() ?? ''),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? now,
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? now,
    );
  }

  SavingsGoal copyWith({
    String? name,
    int? targetCents,
    DateTime? deadline,
    bool clearDeadline = false,
    SavingsGoalStatus? status,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? updatedAt,
  }) {
    return SavingsGoal(
      id: id,
      name: name ?? this.name,
      targetCents: targetCents ?? this.targetCents,
      deadline: clearDeadline ? null : deadline ?? this.deadline,
      status: status ?? this.status,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
