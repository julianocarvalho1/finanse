import 'dart:math' as math;

import 'savings_goal.dart';

class GoalProgress {
  const GoalProgress({required this.goal, required this.savedCents});

  final SavingsGoal goal;
  final int savedCents;

  int get remainingCents => math.max(goal.targetCents - savedCents, 0);

  double get progress =>
      goal.targetCents <= 0 ? 0 : (savedCents / goal.targetCents).clamp(0, 1);

  bool get reachedTarget => savedCents >= goal.targetCents;
}
