// spec 055 (FR-021) — مسح تخزين IndexedDB الخاص بقاعدة الويب بالكامل.
// حذف ملف القاعدة من SQLite WASM بيسيب blocks قديمة يتيمة (بعد آخر طول للملف)
// جواها بيانات المدرس السابق، فبنمسح مخازن IndexedDB نفسها. على أندرويد no-op.
export 'browser_storage_purge_io.dart'
    if (dart.library.js_interop) 'browser_storage_purge_web.dart';
