class Expense {
  final String id;
  final double amount; // Valor da despesa
  final String categoryName; // Nome ou ID da categoria
  final String? description; // Opcional (pode ser nulo)
  final DateTime date;
  final String? paymentMethod; // Opcional
  final bool isRecurring;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.amount,
    required this.categoryName,
    this.description,
    required this.date,
    this.paymentMethod,
    this.isRecurring = false, // Por padrão, não é recorrente
    required this.createdAt,
    required this.updatedAt,
  });

  // Transforma a Despesa em um "Dicionário" (Map) para salvar no banco de dados
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'categoryName': categoryName,
      'description': description,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod,
      'isRecurring': isRecurring ? 1 : 0, // Bancos locais costumam usar 1 e 0 para true/false
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Pega o "Dicionário" do banco de dados e reconstrói a Despesa para mostrar na tela
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      amount: map['amount'] as double,
      categoryName: map['categoryName'] as String,
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      paymentMethod: map['paymentMethod'] as String?,
      isRecurring: (map['isRecurring'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}