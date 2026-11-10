#!/usr/bin/env bash
# tool/deploy_web.sh — spec 055: اختبار + بناء + نشر نسخة الويب على
# https://app.active-class.online (Caddy على نفس الـVPS) بأمر واحد، مع رجوع تلقائي
# لو الفحص بعد النشر فشل.
#
# الاستعمال (من أي مكان، بـ Git Bash):
#   tool/deploy_web.sh                 # اختبارات + بناء + نشر + فحص
#   tool/deploy_web.sh --skip-tests    # من غير الاختبارات (أسرع)
#   tool/deploy_web.sh --build-only    # بناء محلي بس، من غير أي اتصال بالسيرفر
#   tool/deploy_web.sh --rollback      # رجوع للإصدار اللي قبل الحالي
#   tool/deploy_web.sh --yes           # من غير سؤال لو فيه تعديلات غير مدموجة
#   tool/deploy_web.sh --skip-health   # من غير فحص HTTPS بعد النشر
#   tool/deploy_web.sh --reuse-build   # يرفع build/web الموجود من غير اختبارات ولا بناء
#
# متغيرات اختيارية: WEB_HOST WEB_KEY WEB_BASE WEB_URL (راجع تحت).
set -euo pipefail

HOST="${WEB_HOST:-root@active-class.online}"
KEY="${WEB_KEY:-$HOME/.ssh/ovh_key}"
BASE="${WEB_BASE:-/var/www/app.active-class.online}"
URL="${WEB_URL:-https://app.active-class.online}"
KEEP=4 # عدد الإصدارات المحفوظة (الحالي + 3 للرجوع)

SKIP_TESTS=0; BUILD_ONLY=0; ROLLBACK=0; ASSUME_YES=0; SKIP_HEALTH=0; REUSE=0
for a in "$@"; do
  case "$a" in
    --skip-tests) SKIP_TESTS=1 ;;
    --build-only) BUILD_ONLY=1 ;;
    --rollback) ROLLBACK=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --skip-health) SKIP_HEALTH=1 ;;
    --reuse-build) REUSE=1 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "خيار غير معروف: $a (استخدم --help)" >&2; exit 2 ;;
  esac
done

say() { printf '\n== %s\n' "$*"; }
die() { printf '\n[خطأ] %s\n' "$*" >&2; exit 1; }

cd "$(dirname "$0")/.."
[ -f pubspec.yaml ] || die "لازم يتشغّل من مشروع Flutter (مفيش pubspec.yaml)."

ssh_run() { ssh -o ConnectTimeout=15 -o BatchMode=yes -i "$KEY" "$HOST" "$@"; }
need_ssh() {
  [ -f "$KEY" ] || die "مفتاح SSH مش موجود: $KEY"
  ssh_run "true" >/dev/null 2>&1 || die "تعذّر الاتصال بالسيرفر ($HOST)."
}

# ── رجوع للإصدار السابق ─────────────────────────────────────────────────────
if [ "$ROLLBACK" = 1 ]; then
  need_ssh
  say "الرجوع للإصدار السابق"
  ssh_run "set -e
    cur=\$(readlink '$BASE/current' || true)
    prev=\$(ls -1dt '$BASE'/releases/* 2>/dev/null | grep -vxF \"\$cur\" | head -1 || true)
    [ -n \"\$prev\" ] || { echo 'مفيش إصدار سابق للرجوع ليه' >&2; exit 1; }
    ln -sfn \"\$prev\" '$BASE/current'
    echo \"كان: \$cur\"; echo \"بقى:  \$prev\""
  echo "تم. افتح $URL بـ Ctrl+Shift+R."
  exit 0
fi

# ── تعديلات غير مدموجة ──────────────────────────────────────────────────────
dirty="$(git status --porcelain --untracked-files=no || true)"
if [ -n "$dirty" ] && [ "$ASSUME_YES" = 0 ]; then
  say "فيه تعديلات غير مدموجة هتدخل في البناء:"
  echo "$dirty" | head -30
  if [ -t 0 ]; then
    read -r -p "تكمّل برضه؟ [y/N] " ans
    [ "$ans" = "y" ] || [ "$ans" = "Y" ] || die "اتلغى."
  else
    die "فيه تعديلات غير مدموجة. استخدم --yes لو عايز تكمّل."
  fi
fi

# ── اختبارات ────────────────────────────────────────────────────────────────
if [ "$SKIP_TESTS" = 0 ] && [ "$REUSE" = 0 ]; then
  say "تشغيل الاختبارات"
  flutter test || die "الاختبارات فشلت — مش هنبني ولا ننشر."
fi

# ── بناء ────────────────────────────────────────────────────────────────────
if [ "$REUSE" = 1 ]; then
  say "بنستخدم البناء الموجود في build/web (من غير بناء جديد)"
else
say "بناء الويب (release، بدون CDN خارجي)"
# بيعيد المحاولة مرة لو فشل: على أجهزة قليلة الذاكرة مترجم Dart ساعات بيقع
# (Could not start thread DartWorker) ويشتغل في المرة التانية.
if ! flutter build web --release --no-web-resources-cdn; then
  echo "البناء فشل — بنجرّب مرة تانية بعد 10 ثواني (لو فشل تاني اقفل برامج تقيلة)."
  sleep 10
  flutter build web --release --no-web-resources-cdn \
    || die "البناء فشل مرتين (غالبًا ذاكرة الجهاز قليلة، أو خطأ ترجمة في الكود)."
fi
fi
[ -f build/web/main.dart.js ] || die "مفيش build/web/main.dart.js بعد البناء."
if grep -q "PREVIEW_NO_AUTH" build/web/main.dart.js; then
  die "البناء فيه علامة المعاينة PREVIEW_NO_AUTH (بتتخطى الدخول) — ممنوع تتنشر."
fi

if [ "$BUILD_ONLY" = 1 ]; then
  say "تم البناء محليًا في build/web (من غير نشر)."
  exit 0
fi

# ── نشر ─────────────────────────────────────────────────────────────────────
need_ssh
VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}' | tr '+' '_')"
REL="${VERSION}-$(date +%m%d-%H%M)"

say "رفع الإصدار $REL"
tar czf - -C build/web . | ssh_run "set -e
  mkdir -p '$BASE/releases/$REL'
  tar xzf - -C '$BASE/releases/$REL'
  test -f '$BASE/releases/$REL/index.html'"

PREV="$(ssh_run "readlink '$BASE/current' || true")"
ssh_run "ln -sfn '$BASE/releases/$REL' '$BASE/current'"
echo "الإصدار الحالي: $BASE/releases/$REL"

# ── فحص بعد النشر + رجوع تلقائي لو فشل ──────────────────────────────────────
if [ "$SKIP_HEALTH" = 0 ]; then
  say "فحص $URL"
  PW="$(ssh_run "cat /root/.web_gate_pw 2>/dev/null" || true)"
  auth=(); [ -n "$PW" ] && auth=(-u "gate:$PW")
  ok=1
  for p in / /main.dart.js /version.json; do
    code="$(curl -s -o /dev/null -m 40 -w '%{http_code}' "${auth[@]}" "$URL$p" || true)"
    echo "  $p -> $code"
    [ "$code" = "200" ] || ok=0
  done
  if [ "$ok" = 0 ]; then
    if [ -n "$PREV" ]; then
      ssh_run "ln -sfn '$PREV' '$BASE/current'"
      die "الفحص فشل — رجّعنا للإصدار السابق ($PREV)."
    fi
    die "الفحص فشل ومفيش إصدار سابق نرجع له."
  fi
fi

# ── تنضيف القديم (بنسيب KEEP إصدارات، وعمرنا ما بنمسح الحالي) ───────────────
ssh_run "ls -1dt '$BASE'/releases/* 2>/dev/null | tail -n +$((KEEP + 1)) \
  | grep -vxF \"\$(readlink '$BASE/current')\" | xargs -r rm -rf" || true

say "تم النشر ✔  $URL  (الإصدار $REL)"
echo "للرجوع: tool/deploy_web.sh --rollback"
