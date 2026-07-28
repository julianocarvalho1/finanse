import 'package:flutter/foundation.dart';

// Esse é o nosso rádio comunicador global.
// Sempre que o valor dele mudar, quem estiver escutando saberá que deve se atualizar.
final ValueNotifier<int> expenseNotifier = ValueNotifier(0);
