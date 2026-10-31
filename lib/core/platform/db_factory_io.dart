import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// المصنع الافتراضي بتاع sqflite — نفس اللي بيستخدمه `openDatabase()` العام.
DatabaseFactory get appDatabaseFactory => databaseFactory;

/// المسار الكامل لملف القاعدة في مجلد قواعد بيانات التطبيق.
Future<String> appDatabasePath(String name) async =>
    join(await getDatabasesPath(), name);

/// حذف ملف القاعدة (مستخدم على الويب بعد الخروج؛ على أندرويد مش بيتنادى).
Future<void> deleteAppDatabase(String name) async =>
    databaseFactory.deleteDatabase(await appDatabasePath(name));
