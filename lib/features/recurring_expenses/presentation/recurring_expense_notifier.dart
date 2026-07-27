import 'package:flutter/foundation.dart';

/// Notifica as telas quando alguma despesa recorrente é alterada.
///
/// Sempre que uma recorrência for:
///
/// - criada;
/// - editada;
/// - pausada;
/// - reativada;
/// - registrada;
/// - excluída;
///
/// chame:
///
/// recurringExpenseNotifier.notify();
///
/// As telas que estiverem ouvindo esse objeto carregarão os dados novamente.
class RecurringExpenseNotifier extends ChangeNotifier {
  int _revision = 0;

  /// Número incrementado a cada alteração.
  ///
  /// Pode ser usado em testes ou para identificar atualizações sucessivas.
  int get revision => _revision;

  /// Informa que os dados das recorrências foram modificados.
  void notify() {
    _revision++;
    notifyListeners();
  }
}

/// Instância compartilhada por todo o aplicativo.
final RecurringExpenseNotifier recurringExpenseNotifier =
    RecurringExpenseNotifier();
