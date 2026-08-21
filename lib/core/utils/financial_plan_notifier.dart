import 'package:flutter/foundation.dart';

/// Sinaliza alterações em rendas, planejamento mensal ou destinações.
final ValueNotifier<int> financialPlanNotifier = ValueNotifier<int>(0);

void notifyFinancialPlanChanged() {
  financialPlanNotifier.value++;
}
