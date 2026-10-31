import 'package:sqflite_common/sqlite_api.dart' show DatabaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// SQLite WASM فوق IndexedDB — بدون shared worker (الـ worker محتاج
/// `dart run sqflite_common_ffi_web:setup` وبيفشل على بيئتنا؛ وكمان
/// الويب عندنا تاب واحد نشط فقط، فمفيش احتياج لمشاركة القاعدة بين تابات).
/// محتاج `web/sqlite3.wasm` بنفس نسخة حزمة sqlite3 المقفولة في pubspec.lock.
DatabaseFactory get appDatabaseFactory => databaseFactoryFfiWebNoWebWorker;

/// على الويب مفيش مجلدات — الاسم نفسه هو مفتاح القاعدة في IndexedDB.
Future<String> appDatabasePath(String name) async => name;

/// حذف قاعدة المتصفح (IndexedDB) بالكامل. نظام ملفات SQLite WASM بيخزّن
/// الاسم بشرطة مائلة في الأول ("/active_class.db") وxDelete بيتجاهل بصمت
/// أي مسار مش مطابق، فنجرّب الشكلين.
Future<void> deleteAppDatabase(String name) async {
  for (final p in {name, '/$name'}) {
    try {
      await appDatabaseFactory.deleteDatabase(p);
    } catch (_) {}
  }
}
