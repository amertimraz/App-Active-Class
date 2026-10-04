# Phase 1 Data Model: المساعد والامتحانات الإلكترونية

## Supabase

### `team_members` (أعمدة جديدة)
| العمود | النوع | ملاحظة |
|---|---|---|
| `can_manage_online_exams` | boolean NOT NULL DEFAULT false | صلاحية إدارة الامتحانات الإلكترونية؛ المالك يتجاهلها (دايمًا true في الواجهة) |
| `firebase_uid` | text NULL | Firebase Anonymous uid لجهاز العضو، يسجّله العضو بنفسه عبر RPC؛ يُستخدم لتفويض Firestore |

### `teams` (أعمدة جديدة، يكتبها المالك فقط)
| العمود | النوع | ملاحظة |
|---|---|---|
| `portal_slug` | text NULL | slug رابط الطلاب المشتق من كود ترخيص المدرس (غير قابل للعكس عمليًا) |
| `portal_enabled` | boolean NOT NULL DEFAULT false | إضافة البوابة مفعّلة عند المدرس |
| `portal_expires_at` | timestamptz NULL | تاريخ انتهاء الإضافة (NULL = مدى الحياة) |

### RPCs (security definer)
- `set_team_portal(_team_id uuid, _slug text, _enabled boolean, _expires_at timestamptz)` — `where id = _team_id and owner_id = auth.uid()`.
- `set_my_firebase_uid(_team_id uuid, _uid text)` — `update team_members set firebase_uid = _uid where team_id = _team_id and user_id = auth.uid()`.

## Firestore

### `online_exams/{slug}` (حقل جديد، يكتبه المالك فقط)
| الحقل | النوع | ملاحظة |
|---|---|---|
| `coOwnerUids` | array<string> | uids المفوّضة بالكتابة تحت `exams/**` فقط |

القاعدة: `_oeOwner(slug)` = `ownerUid == uid` أو `uid in coOwnerUids`.

## SQLite (محلي)
- **لا تغيير** في الجداول للجزء الأساسي. حالة الفريق عند المساعد (الصلاحية، slug، enabled، expires) في الذاكرة + `app_settings` (مفاتيح `team_portal_*`) لاستعادة الأوفلاين.
- (US4 فقط، اختياري) `exams.created_by_name TEXT` — DB v37.

## كيانات Dart
- `TeamModeService`: `canManageOnlineExams` (Rx)، `teamPortalSlug`/`teamPortalEnabled`/`teamPortalExpiresAt` (Rx، عند المساعد)، getters: `canManageOnlineExamsNow`, `isAssistant`.
- `OnlineExamAccess { locked, readOnly, canCreate }` — ناتج الدالة الصرفة.
