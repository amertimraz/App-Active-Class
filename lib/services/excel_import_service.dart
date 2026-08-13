// lib/services/excel_import_service.dart
// خدمة استيراد الطلاب من ملف Excel: توليد القالب + قراءة وتحليل الملف المرفوع.

import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:media_store_plus/media_store_plus.dart';

import 'package:active_class/models/group_model.dart';

/// نتيجة تحليل صف واحد من ملف الاستيراد.
class ImportRowResult {
  final int rowNumber; // رقم الصف في الملف (1-based, بعد صف العناوين)
  final String name;
  final double? price; // null = استخدم رسوم المجموعة
  final String? phone;
  final DateTime? birthDate;
  final DateTime? attendanceStart;
  final String? code; // null = يتولد تلقائياً — أو كود جاهز (من كرت مطبوع مسبقاً مثلاً)
  final String? error; // null = الصف صالح

  ImportRowResult({
    required this.rowNumber,
    required this.name,
    this.price,
    this.phone,
    this.birthDate,
    this.attendanceStart,
    this.code,
    this.error,
  });

  bool get isValid => error == null;
}

class ExcelImportService {
  static final ExcelImportService _i = ExcelImportService._();
  factory ExcelImportService() => _i;
  ExcelImportService._();

  static const _sheetName = 'الطلاب';
  static const _headers = [
    'اسم الطالب',
    'رقم ولي الأمر',
    'الرسوم',
    'تاريخ الميلاد',
    'تاريخ بداية الحضور',
    'الكود (اختياري)',
  ];

  // ── بناء ملف القالب ────────────────────────────────────────────────
  Future<File> buildTemplateFile({required Group group}) async {
    final workbook = xl.Excel.createExcel();
    // شيت افتراضي بيتعمل تلقائي باسم "Sheet1" — نعيد تسميته ونحذف الباقي.
    final defaultSheet = workbook.getDefaultSheet();
    workbook.rename(defaultSheet!, _sheetName);
    final sheet = workbook[_sheetName];

    sheet.appendRow(_headers.map((h) => xl.TextCellValue(h)).toList());

    final examplePrice = group.price != null
        ? group.price!.toStringAsFixed(0)
        : '';
    sheet.appendRow([
      xl.TextCellValue('أحمد محمد (مثال)'),
      xl.TextCellValue('01012345678'),
      xl.TextCellValue(examplePrice),
      xl.TextCellValue('15/9/2012'),
      xl.TextCellValue(''),
      xl.TextCellValue(''),
    ]);

    for (var i = 0; i < _headers.length; i++) {
      sheet.setColumnWidth(i, 22);
    }

    final bytes = workbook.encode();
    if (bytes == null) {
      throw Exception('تعذر إنشاء ملف القالب');
    }

    final dir = await getTemporaryDirectory();
    final safeGroupName = group.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/قالب_استيراد_الطلاب_$safeGroupName.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> shareTemplate(File file, {required Group group}) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'قالب استيراد طلاب مجموعة ${group.name}',
    );
  }

  /// حفظ القالب مباشرة في مجلد Downloads/ActiveClass عبر MediaStore،
  /// كبديل لقائمة المشاركة على أجهزة ما بتعرضش خيار "حفظ في الملفات".
  Future<String?> saveTemplateToDownloads(File file) async {
    try {
      await MediaStore.ensureInitialized();
      MediaStore.appFolder = 'ActiveClass';
      final saveInfo = await MediaStore().saveFile(
        tempFilePath: file.path,
        dirType: DirType.download,
        dirName: DirName.download,
      );
      return saveInfo?.uri.toString();
    } catch (_) {
      return null;
    }
  }

  // ── تحليل الملف المرفوع ────────────────────────────────────────────
  List<ImportRowResult> parseFile(File file, {required Group group}) {
    final bytes = file.readAsBytesSync();
    final workbook = xl.Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) return [];

    final sheet = workbook.tables[_sheetName] ?? workbook.tables.values.first;

    final results = <ImportRowResult>[];
    var rowNumber = 0;

    for (var r = 1; r < sheet.maxRows; r++) {
      final row = sheet.row(r);
      if (_isRowEmpty(row)) continue;
      rowNumber++;

      final name = _cellText(row, 0).trim();
      final phoneRaw = _cellText(row, 1).trim();
      final priceRaw = _cellText(row, 2).trim();

      if (name.isEmpty) {
        results.add(ImportRowResult(
          rowNumber: rowNumber,
          name: name,
          error: 'اسم الطالب فارغ',
        ));
        continue;
      }

      final price = double.tryParse(priceRaw.replaceAll(',', ''));
      final birthDate = _cellDate(row, 3);
      final attendanceStart = _cellDate(row, 4);
      final codeRaw = _cellText(row, 5).trim();

      results.add(ImportRowResult(
        rowNumber: rowNumber,
        name: name,
        price: price,
        phone: phoneRaw.isEmpty ? null : phoneRaw,
        birthDate: birthDate,
        attendanceStart: attendanceStart,
        code: codeRaw.isEmpty ? null : codeRaw,
      ));
    }

    return results;
  }

  bool _isRowEmpty(List<xl.Data?> row) {
    for (final cell in row) {
      final v = cell?.value;
      if (v != null && v.toString().trim().isNotEmpty) return false;
    }
    return true;
  }

  String _cellText(List<xl.Data?> row, int index) {
    if (index >= row.length) return '';
    final v = row[index]?.value;
    if (v == null) return '';
    return v.toString();
  }

  /// يقرأ خلية تاريخ سواء كانت مكتوبة كنص ("يوم/شهر/سنة") أو خلية تاريخ
  /// حقيقية من إكسل (لو المستخدم استخدم منتقي التاريخ بتاع إكسل بدل ما
  /// يكتب النص يدويًا) — لو اعتمدنا على toString() بس كنا هنفقد التاريخ
  /// بصمت في الحالة التانية.
  DateTime? _cellDate(List<xl.Data?> row, int index) {
    if (index >= row.length) return null;
    final v = row[index]?.value;
    if (v == null) return null;
    if (v is xl.DateCellValue) return DateTime(v.year, v.month, v.day);
    if (v is xl.DateTimeCellValue) {
      return DateTime(v.year, v.month, v.day, v.hour, v.minute, v.second);
    }
    return _tryParseDate(v.toString().trim());
  }

  /// يحاول تحليل تاريخ نصي بصيغة يوم/شهر/سنة أو سنة-شهر-يوم (ISO)،
  /// يقبل فواصل - أو / أو . وأرقام سنة بحرفين أو أربعة.
  DateTime? _tryParseDate(String raw) {
    if (raw.isEmpty) return null;
    final parts = raw
        .split(' ')
        .first // تجاهل جزء الوقت لو الخلية طلعت "yyyy-MM-dd HH:mm:ss"
        .split(RegExp(r'[/\-.]'))
        .map((p) => p.trim())
        .toList();
    if (parts.length != 3) return null;
    final p0 = int.tryParse(parts[0]);
    final p1 = int.tryParse(parts[1]);
    final p2 = int.tryParse(parts[2]);
    if (p0 == null || p1 == null || p2 == null) return null;

    // سنة-شهر-يوم (ISO) لو أول جزء 4 أرقام، وإلا يوم/شهر/سنة (الافتراضي).
    int day, month, year;
    if (parts[0].length == 4) {
      year = p0;
      month = p1;
      day = p2;
    } else {
      day = p0;
      month = p1;
      year = p2;
      if (year < 100) year += 2000;
    }

    try {
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) {
        return null;
      }
      return date;
    } catch (_) {
      return null;
    }
  }
}
