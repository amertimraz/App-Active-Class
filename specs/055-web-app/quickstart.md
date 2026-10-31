# Quickstart: نشر وتحقق نسخة الويب (055)

> **لم يُنفّذ أي خطوة من دول.** كله في انتظار موافقة المستخدم.

## 1. DNS (المستخدم من لوحة مزوّد الدومين)

| النوع | الاسم | القيمة | TTL |
|---|---|---|---|
| A | `app` | `192.99.145.122` | 300 |
| AAAA | `app` | (نفس قيمة AAAA للدومين الأساسي لو موجودة، وإلا لا شيء) | 300 |

التحقق: `nslookup app.active-class.online` يرجّع `192.99.145.122`.

## 2. Caddy (مش Nginx — السيرفر شغّال Caddy v2.11)

```bash
ssh -i ~/.ssh/ovh_key root@active-class.online
cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.bak.$(date +%Y%m%d%H%M%S)
mkdir -p /var/www/app.active-class.online/releases
```

البلوك المضاف في آخر `/etc/caddy/Caddyfile`:

```caddyfile
app.active-class.online {
    root * /var/www/app.active-class.online/current
    encode zstd gzip

    header {
        Strict-Transport-Security "max-age=31536000"
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
        Permissions-Policy "camera=(self), microphone=(), geolocation=()"
        -Server
    }

    # الملفات اللي لازم تتجدد فورًا بعد كل نشر
    @nocache path / /index.html /flutter_bootstrap.js /flutter_service_worker.js /version.json /manifest.json
    header @nocache Cache-Control "no-cache, no-store, must-revalidate"

    # الأصول (CanvasKit/wasm/الخطوط/main.dart.js المرتبط بالإصدار عبر bootstrap)
    @assets path /canvaskit/* /assets/* /icons/* *.wasm
    header @assets Cache-Control "public, max-age=604800"

    @wasm path *.wasm
    header @wasm Content-Type "application/wasm"

    try_files {path} /index.html
    file_server
}
```

```bash
caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy
```

Caddy هيطلّع شهادة Let's Encrypt تلقائيًا أول طلب (لازم DNS يكون اتنشر). **السيرفر عليه دومينات تانية (zmenu/wasla/amertimraz) — `validate` قبل `reload` إجباري.**

## 3. البناء والنشر (`tool/deploy_web.sh` — يتكتب في المرحلة 6)

```bash
flutter build web --release --no-web-resources-cdn --base-href / \
  --dart-define=APP_WEB=true
V=$(grep '^version:' pubspec.yaml | awk '{print $2}' | tr '+' '_')
rsync -az build/web/ root@active-class.online:/var/www/app.active-class.online/releases/$V/
ssh root@active-class.online "ln -sfn /var/www/app.active-class.online/releases/$V /var/www/app.active-class.online/current && ls -1dt /var/www/app.active-class.online/releases/* | tail -n +4 | xargs -r rm -rf"
```

الرجوع لإصدار سابق: `ln -sfn .../releases/<old> .../current` (فوري، من غير reload).

## 4. Supabase

- تطبيق `supabase/migration_web_access.sql` (contracts/supabase-web-access.md) عبر SSH كـ `supabase_admin`.
- تشغيل اختبارات SQL الأربعة في العقد.
- تأكيد CORS: من `https://app.active-class.online` طلب `OPTIONS` لـ `https://auth.active-class.online/rest/v1/` يرجّع `Access-Control-Allow-Origin`.

## 5. Firebase

- لو App Check **Enforced** على Firestore (Q9): إنشاء مفتاح reCAPTCHA v3 للدومين وتفعيل `ReCaptchaV3Provider` على الويب.
- إضافة `app.active-class.online` في Authorized domains (لازم لو فعّلنا Google Sign-In لاحقًا؛ مش لازم للـ anonymous).

## 6. Checklist التحقق (Chrome + Edge، 1366×768 و1920×1080)

- [ ] متصفح جديد → شاشة دخول بس (مفيش تجربة/كود).
- [ ] مدرس غير مفعّل → شاشة القفل، وNetwork tab مفيهوش أي select على جداول الفريق.
- [ ] مدرس مفعّل → سحب أول مرة بنسبة → الرئيسية بنفس أعداد الموبايل.
- [ ] حضور يدوي، حضور QR بكاميرا اللابتوب، حضور بقارئ USB.
- [ ] دفعة جديدة (شهري + بالحصة) → تظهر على الموبايل ≤60ث.
- [ ] تقرير طالب PDF + طباعة شهادات بالعربي.
- [ ] تصدير Excel وPDF وصورة QR → تنزيل.
- [ ] امتحان أونلاين: إنشاء/نشر/نتائج.
- [ ] الأدمن يقفل الويب → القفل يظهر ≤5د.
- [ ] تابين → التاني يعرض "مفتوح في تاب تاني".
- [ ] تسجيل خروج → IndexedDB والـ localStorage الخاصين بالمستخدم اتمسحوا.
- [ ] نشر إصدار جديد → التاب المفتوح يعرض "نسخة جديدة — حدّث".
- [ ] بناء أندرويد direct وplay → اختبار سريع على الجهاز بدون تراجع.
- [ ] الإعدادات → "تراخيص البرمجيات" تفتح.
