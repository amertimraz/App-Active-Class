#!/usr/bin/env bash
# supabase/docker/deploy.sh
#
# سكريبت نشر تلقائي — يعمل خطوات 2 لحد 6 من docs/auth_deployment.md
# دفعة واحدة: توليد الأسرار، تجهيز .env و kong.yml، تشغيل الـ stack،
# وتطبيق schema.sql. شغّله مرة واحدة بس من جوه مجلد supabase/docker
# على الـ VPS، بعد ما يكون عندك Docker و Docker Compose و Node مثبتين.
#
# الاستخدام:
#   chmod +x deploy.sh
#   ./deploy.sh auth.yourdomain.com
#
# لسه محتاج منك بعد كده (خطوات مش ممكن تتأتمت من هنا):
#   - خطوة 7: توصيل الدومين ده بمنفذ Kong (8000) في الـ reverse proxy
#     الموجود عندك (nginx/Caddy) — راجع المثال في auth_deployment.md.
#   - خطوة 8: نسخ ANON_KEY الظاهر في آخر السكريبت لملف
#     lib/config/supabase_config.dart في الريبو.

set -euo pipefail

DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
  echo "الاستخدام: ./deploy.sh auth.yourdomain.com"
  exit 1
fi

command -v docker >/dev/null 2>&1 || { echo "Docker مش مثبت — ثبّته الأول"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "Node مش مثبت — ثبّته الأول (لازم لتوليد المفاتيح)"; exit 1; }

echo "→ توليد الأسرار..."
POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)
JWT_SECRET=$(openssl rand -base64 32 | tr -d '/+=' | head -c 40)

KEYS_OUTPUT=$(node generate_keys.js "$JWT_SECRET")
ANON_KEY=$(echo "$KEYS_OUTPUT" | grep '^ANON_KEY=' | cut -d= -f2-)
SERVICE_ROLE_KEY=$(echo "$KEYS_OUTPUT" | grep '^SERVICE_ROLE_KEY=' | cut -d= -f2-)

echo "→ تجهيز .env..."
cat > .env <<EOF
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=postgres
POSTGRES_PORT=5432

JWT_SECRET=$JWT_SECRET
ANON_KEY=$ANON_KEY
SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY

API_EXTERNAL_URL=https://$DOMAIN
SITE_URL=https://$DOMAIN

KONG_HTTP_PORT=8000
EOF
chmod 600 .env

echo "→ تجهيز kong.yml..."
sed -e "s/__ANON_KEY__/$ANON_KEY/" -e "s/__SERVICE_ROLE_KEY__/$SERVICE_ROLE_KEY/" \
  kong.yml.template > kong.yml

echo "→ تشغيل الـ stack (Postgres + Auth + Kong)..."
docker compose up -d

echo "→ الانتظار لحد ما قاعدة البيانات تبقى جاهزة..."
until docker compose exec -T db pg_isready -U postgres >/dev/null 2>&1; do
  sleep 2
done

echo "→ تطبيق schema.sql..."
docker compose exec -T db psql -U postgres -d postgres -f /schema.sql

echo ""
echo "✅ الـ stack شغال محليًا على المنفذ ${KONG_HTTP_PORT:-8000}."
echo ""
echo "الخطوات المتبقية عندك (مش ممكن تتأتمت من هنا):"
echo "  1) وصّل الدومين $DOMAIN بمنفذ 127.0.0.1:8000 في الـ reverse proxy بتاعك."
echo "  2) حدّث lib/config/supabase_config.dart في الريبو بالقيم دي:"
echo ""
echo "     static const String url = 'https://$DOMAIN';"
echo "     static const String anonKey = '$ANON_KEY';"
echo ""
echo "(الـ .env فيه كل الأسرار — خليه محفوظ على السيرفر بس، ومتشاركوش)."
