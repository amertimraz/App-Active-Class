// spec 055 — مصنع قاعدة البيانات حسب المنصّة (استيراد شرطي).
//
// على أندرويد/ويندوز: نفس السلوك القديم بالحرف (databaseFactory الافتراضي
// بتاع sqflite + getDatabasesPath). على الويب: SQLite WASM فوق IndexedDB
// عبر sqflite_common_ffi_web — والقاعدة هناك كاش بيتملي من مزامنة الفريق.
export 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';
