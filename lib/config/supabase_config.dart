// lib/config/supabase_config.dart
//
// إعدادات الاتصال بسيرفر Supabase المستضاف ذاتيًا على الـ VPS — خاص
// بنظام تسجيل الدخول المستقل فقط (منفصل عن Firebase الخاص بالترخيص).
// راجع docs/auth_deployment.md لخطوات تجهيز السيرفر.
//
// القيمتان دول آمن وضعهما هنا داخل الكود (client-side) — الـ anon key
// مصمم من Supabase عشان يُنشر مع التطبيق، والحماية الفعلية بتكون على
// مستوى قاعدة البيانات نفسها (Row Level Security) مش إخفاء المفتاح.
class SupabaseConfig {
  static const String url = 'https://auth.active-class.online';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzg2Nzg0MDQ3LCJleHAiOjIxMDIxNDQwNDd9.tCeiDwNKkm1ah6-r6Akw0wJ2eiInvPz_Suxx9LHmQ6Q';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
