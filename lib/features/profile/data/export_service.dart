import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart' as csv_package;
import 'package:excel/excel.dart' as excel_package;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';

/// Formatos de arquivo disponíveis para exportação.
enum ExportFileFormat { csv, xlsx, pdf }

extension ExportFileFormatExtension on ExportFileFormat {
  String get label {
    switch (this) {
      case ExportFileFormat.csv:
        return 'CSV';

      case ExportFileFormat.xlsx:
        return 'XLSX';

      case ExportFileFormat.pdf:
        return 'PDF';
    }
  }

  String get extension {
    switch (this) {
      case ExportFileFormat.csv:
        return 'csv';

      case ExportFileFormat.xlsx:
        return 'xlsx';

      case ExportFileFormat.pdf:
        return 'pdf';
    }
  }

  String get mimeType {
    switch (this) {
      case ExportFileFormat.csv:
        return 'text/csv';

      case ExportFileFormat.xlsx:
        return 'application/vnd.openxmlformats-officedocument.'
            'spreadsheetml.sheet';

      case ExportFileFormat.pdf:
        return 'application/pdf';
    }
  }
}

/// Informações sobre um arquivo produzido pelo serviço.
class ExportedExpenseFile {
  const ExportedExpenseFile({
    required this.file,
    required this.format,
    required this.recordCount,
    required this.totalAmount,
    required this.generatedAt,
  });

  final File file;
  final ExportFileFormat format;
  final int recordCount;
  final double totalAmount;
  final DateTime generatedAt;

  String get fileName {
    return path.basename(file.path);
  }
}

/// Erro conhecido ocorrido durante uma exportação.
class ExportException implements Exception {
  const ExportException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}

/// Gera e compartilha relatórios com as despesas reais salvas no SQLite.
class ExportService {
  ExportService({ExpenseRepository? expenseRepository})
    : _expenseRepository = expenseRepository ?? ExpenseRepository();

  static final ExportService instance = ExportService();

  final ExpenseRepository _expenseRepository;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  final DateFormat _timeFormat = DateFormat('HH:mm');

  final DateFormat _fileDateFormat = DateFormat('yyyyMMdd_HHmmss');

  final NumberFormat _moneyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$',
    decimalDigits: 2,
  );

  final NumberFormat _csvAmountFormat = NumberFormat('0.00', 'pt_BR');

  /// Gera um arquivo a partir do nome exibido na interface.
  Future<ExportedExpenseFile> generateByLabel(String formatLabel) async {
    final ExportFileFormat format = _parseFormat(formatLabel);

    return generate(format);
  }

  /// Busca todas as despesas e produz o arquivo solicitado.
  Future<ExportedExpenseFile> generate(ExportFileFormat format) async {
    final List<Expense> expenses = await _expenseRepository.getAllExpenses();

    if (expenses.isEmpty) {
      throw const ExportException(
        'Não existem gastos cadastrados para exportar.',
      );
    }

    final DateTime generatedAt = DateTime.now();

    final Directory temporaryDirectory = await getTemporaryDirectory();

    final Directory exportDirectory = Directory(
      path.join(temporaryDirectory.path, 'finanse_exports'),
    );

    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }

    final String fileName =
        'finanse_despesas_'
        '${_fileDateFormat.format(generatedAt)}.'
        '${format.extension}';

    final File file = File(path.join(exportDirectory.path, fileName));

    switch (format) {
      case ExportFileFormat.csv:
        await _writeCsv(file: file, expenses: expenses);

      case ExportFileFormat.xlsx:
        await _writeXlsx(file: file, expenses: expenses);

      case ExportFileFormat.pdf:
        await _writePdf(
          file: file,
          expenses: expenses,
          generatedAt: generatedAt,
        );
    }

    if (!await file.exists()) {
      throw const ExportException('O arquivo não pôde ser criado.');
    }

    final int fileSize = await file.length();

    if (fileSize <= 0) {
      throw const ExportException('O arquivo foi criado sem conteúdo.');
    }

    return ExportedExpenseFile(
      file: file,
      format: format,
      recordCount: expenses.length,
      totalAmount: _calculateTotal(expenses),
      generatedAt: generatedAt,
    );
  }

  /// Abre o painel de compartilhamento do Android.
  Future<void> share(ExportedExpenseFile exportedFile) async {
    final String recordLabel = exportedFile.recordCount == 1
        ? 'registro'
        : 'registros';

    await SharePlus.instance.share(
      ShareParams(
        title: 'Exportar relatório do Finanse',
        subject: 'Relatório financeiro do Finanse',
        text:
            'Relatório do Finanse com '
            '${exportedFile.recordCount} $recordLabel.',
        files: <XFile>[
          XFile(exportedFile.file.path, mimeType: exportedFile.format.mimeType),
        ],
        fileNameOverrides: <String>[exportedFile.fileName],
      ),
    );
  }

  Future<void> _writeCsv({
    required File file,
    required List<Expense> expenses,
  }) async {
    final List<List<dynamic>> rows = <List<dynamic>>[
      <dynamic>[
        'Data',
        'Horário',
        'Categoria',
        'Descrição',
        'Valor',
        'Forma de pagamento',
        'Recorrente',
        'Observações',
        'Identificador',
      ],
    ];

    for (final Expense expense in expenses) {
      rows.add(<dynamic>[
        _dateFormat.format(expense.date),
        _timeFormat.format(expense.date),
        expense.categoryName,
        _descriptionFor(expense),
        _csvAmountFormat.format(expense.amount),
        _paymentMethodFor(expense),
        expense.isRecurring ? 'Sim' : 'Não',
        _notesFor(expense),
        expense.id,
      ]);
    }

    final String csvContent = csv_package.excel.encode(rows);

    await file.writeAsBytes(utf8.encode(csvContent), flush: true);
  }

  Future<void> _writeXlsx({
    required File file,
    required List<Expense> expenses,
  }) async {
    final excel_package.Excel workbook = excel_package.Excel.createExcel();

    final String? defaultSheet = workbook.getDefaultSheet();

    if (defaultSheet != null && defaultSheet != 'Despesas') {
      workbook.rename(defaultSheet, 'Despesas');
    }

    final excel_package.Sheet sheet = workbook['Despesas'];

    sheet.appendRow(<excel_package.CellValue>[
      excel_package.TextCellValue('Data'),
      excel_package.TextCellValue('Horário'),
      excel_package.TextCellValue('Categoria'),
      excel_package.TextCellValue('Descrição'),
      excel_package.TextCellValue('Valor'),
      excel_package.TextCellValue('Forma de pagamento'),
      excel_package.TextCellValue('Recorrente'),
      excel_package.TextCellValue('Observações'),
      excel_package.TextCellValue('Identificador'),
    ]);

    for (final Expense expense in expenses) {
      sheet.appendRow(<excel_package.CellValue>[
        excel_package.TextCellValue(_dateFormat.format(expense.date)),
        excel_package.TextCellValue(_timeFormat.format(expense.date)),
        excel_package.TextCellValue(expense.categoryName),
        excel_package.TextCellValue(_descriptionFor(expense)),
        excel_package.DoubleCellValue(expense.amount),
        excel_package.TextCellValue(_paymentMethodFor(expense)),
        excel_package.TextCellValue(expense.isRecurring ? 'Sim' : 'Não'),
        excel_package.TextCellValue(_notesFor(expense)),
        excel_package.TextCellValue(expense.id),
      ]);
    }

    final List<int>? bytes = workbook.save();

    if (bytes == null || bytes.isEmpty) {
      throw const ExportException(
        'Não foi possível montar a planilha do Excel.',
      );
    }

    await file.writeAsBytes(bytes, flush: true);
  }

  Future<void> _writePdf({
    required File file,
    required List<Expense> expenses,
    required DateTime generatedAt,
  }) async {
    final pw.Document document = pw.Document(
      title: 'Relatório de despesas do Finanse',
      author: 'Finanse',
      creator: 'Finanse',
      subject: 'Relatório financeiro pessoal',
    );

    final double totalAmount = _calculateTotal(expenses);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Text(
                  'Finanse',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green700,
                  ),
                ),
                pw.Text(
                  'Relatório de despesas',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Text(
                  'Gerado pelo Finanse',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Página ${context.pageNumber} '
                  'de ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return <pw.Widget>[
            pw.Text(
              'Relatório de despesas',
              style: pw.TextStyle(
                fontSize: 23,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Gerado em '
              '${_dateFormat.format(generatedAt)} '
              'às ${_timeFormat.format(generatedAt)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 18),
            _buildPdfSummary(
              recordCount: expenses.length,
              totalAmount: totalAmount,
            ),
            pw.SizedBox(height: 18),
            _buildPdfTable(expenses),
          ];
        },
      ),
    );

    final List<int> bytes = await document.save();

    if (bytes.isEmpty) {
      throw const ExportException('Não foi possível montar o documento PDF.');
    }

    await file.writeAsBytes(bytes, flush: true);
  }

  pw.Widget _buildPdfSummary({
    required int recordCount,
    required double totalAmount,
  }) {
    final String recordLabel = recordCount == 1
        ? 'despesa registrada'
        : 'despesas registradas';

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                'REGISTROS',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '$recordCount $recordLabel',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              pw.Text(
                'TOTAL GASTO',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _moneyFormat.format(totalAmount),
                style: pw.TextStyle(
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTable(List<Expense> expenses) {
    final List<pw.TableRow> rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey800),
        children: <pw.Widget>[
          _pdfCell('Data e hora', isHeader: true),
          _pdfCell('Categoria', isHeader: true),
          _pdfCell('Descrição', isHeader: true),
          _pdfCell('Pagamento', isHeader: true),
          _pdfCell('Tipo', isHeader: true),
          _pdfCell(
            'Valor',
            isHeader: true,
            alignment: pw.Alignment.centerRight,
          ),
        ],
      ),
    ];

    for (int index = 0; index < expenses.length; index++) {
      final Expense expense = expenses[index];

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: index.isEven ? PdfColors.white : PdfColors.grey100,
          ),
          children: <pw.Widget>[
            _pdfCell(
              '${_dateFormat.format(expense.date)} '
              '${_timeFormat.format(expense.date)}',
            ),
            _pdfCell(expense.categoryName),
            _pdfCell(_descriptionFor(expense)),
            _pdfCell(_paymentMethodFor(expense)),
            _pdfCell(expense.isRecurring ? 'Recorrente' : 'Avulsa'),
            _pdfCell(
              _moneyFormat.format(expense.amount),
              alignment: pw.Alignment.centerRight,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(1.35),
        1: const pw.FlexColumnWidth(1.25),
        2: const pw.FlexColumnWidth(2.4),
        3: const pw.FlexColumnWidth(1.4),
        4: const pw.FlexColumnWidth(1.1),
        5: const pw.FlexColumnWidth(1.15),
      },
      children: rows,
    );
  }

  pw.Widget _pdfCell(
    String text, {
    bool isHeader = false,
    pw.Alignment alignment = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.2,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.grey900,
        ),
      ),
    );
  }

  ExportFileFormat _parseFormat(String formatLabel) {
    switch (formatLabel.trim().toUpperCase()) {
      case 'CSV':
        return ExportFileFormat.csv;

      case 'XLSX':
      case 'EXCEL':
        return ExportFileFormat.xlsx;

      case 'PDF':
        return ExportFileFormat.pdf;

      default:
        throw ExportException('O formato "$formatLabel" não é compatível.');
    }
  }

  double _calculateTotal(List<Expense> expenses) {
    return expenses.fold<double>(0, (double total, Expense expense) {
      return total + expense.amount;
    });
  }

  String _descriptionFor(Expense expense) {
    final String? description = expense.description?.trim();

    if (description == null || description.isEmpty) {
      return 'Sem descrição';
    }

    return description;
  }

  String _paymentMethodFor(Expense expense) {
    final String? paymentMethod = expense.paymentMethod?.trim();

    if (paymentMethod == null || paymentMethod.isEmpty) {
      return 'Não informado';
    }

    return paymentMethod;
  }

  String _notesFor(Expense expense) {
    final String? notes = expense.notes?.trim();

    if (notes == null || notes.isEmpty) {
      return '';
    }

    return notes;
  }
}
