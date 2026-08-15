# نشر نظام تسجيل الدخول (Supabase مستضاف ذاتيًا على الـ VPS)

خطوات تجهيز السيرفر لتشغيل نظام تسجيل الدخول المستقل (رقم تليفون +
باسورد)، منفصل تمامًا عن Firebase الخاص بالترخيص. الملفات الجاهزة
موجودة في [`supabase/docker/`](../supabase/docker).

## 0. المتطلبات (عندك بالفعل)
- VPS بمواصفات كافية (2GB RAM على الأقل).
- دومين/subdomain (مثلاً `auth.yourdomain.com`) وشهادة SSL.
- Docker و Docker Compose مثبتين على السيرفر.

## 1. انسخ الملفات للسيرفر

انسخ مجلد `supabase/` كامل (فيه `schema.sql` و`docker/`) لأي مكان على
الـ VPS، مثلاً `/opt/active-class-auth/`.

## 2. جهّز ملف `.env`

```bash
cd /opt/active-class-auth/docker
cp .env.example .env
```

املأ فيه:
- `POSTGRES_PASSWORD` — باسورد قوي عشوائي.
- `JWT_SECRET` — ولّده بـ: `openssl rand -base64 32`
- `API_EXTERNAL_URL` و `SITE_URL` — رابط الدومين بتاعك، مثلاً
  `https://auth.yourdomain.com`.

## 3. ولّد `ANON_KEY` و `SERVICE_ROLE_KEY`

```bash
node generate_keys.js YOUR_JWT_SECRET
```

(محتاج Node مثبت على السيرفر — أي نسخة حديثة كفاية، السكريبت من غير
أي مكتبات خارجية). انسخ الناتج لقيم `ANON_KEY` و `SERVICE_ROLE_KEY`
في `.env`.

## 4. جهّز `kong.yml` من القالب

```bash
source .env
sed -e "s/__ANON_KEY__/$ANON_KEY/" -e "s/__SERVICE_ROLE_KEY__/$SERVICE_ROLE_KEY/" \
  kong.yml.template > kong.yml
```

## 5. شغّل الـ stack

```bash
docker compose up -d
```

هيشغّل `db` (Postgres) و`auth` (GoTrue) و`kong` (بوابة الـ API على
المنفذ 8000 محليًا). لو عايز لوحة إدارة (Studio) لمراجعة المستخدمين
يدويًا: `docker compose --profile studio up -d`.

## 6. طبّق الـ schema

```bash
docker compose exec db psql -U postgres -d postgres -f /schema.sql
```

## 7. اربط الدومين بـ Kong عبر الـ reverse proxy الموجود عندك

وجّه `https://auth.yourdomain.com` لمنفذ Kong المحلي (`127.0.0.1:8000`
افتراضيًا). مثال nginx:

```nginx
location / {
    proxy_pass http://127.0.0.1:8000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

(أو الكتلة المكافئة في Caddy — `reverse_proxy 127.0.0.1:8000` سطر
واحد بما إن الشهادة عندك مُدارة بالفعل).

## 8. حدّث إعدادات التطبيق

في [`lib/config/supabase_config.dart`](../lib/config/supabase_config.dart):

```dart
static const String url = 'https://auth.yourdomain.com';
static const String anonKey = '...'; // قيمة ANON_KEY من .env
```

الـ anon key آمن نشره داخل التطبيق — الحماية الفعلية على مستوى
قاعدة البيانات نفسها (Row Level Security في `schema.sql`).
`SERVICE_ROLE_KEY` سرّي تمامًا ولا يظهر في التطبيق أبدًا — يُستخدم
فقط لو احتجت وصول إداري مباشر من السيرفر لاحقًا.

## 9. اختبار سريع

```bash
curl -i https://auth.yourdomain.com/health
```

المفروض يرجّع رد 200. بعدها جرّب "إنشاء حساب" من شاشة الحساب في
التطبيق وتأكد إن صف جديد ظهر في جدول `profiles`.
