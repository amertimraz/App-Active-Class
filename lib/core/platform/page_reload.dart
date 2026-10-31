// spec 055 — إعادة تحميل الصفحة على الويب (بعد تسجيل الخروج ومسح البيانات
// المحلية) عشان كل الـcontrollers اللي في الذاكرة تتصفّر. على أندرويد no-op.
export 'page_reload_io.dart'
    if (dart.library.js_interop) 'page_reload_web.dart';
