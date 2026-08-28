-- supabase/migration_student_archiving.sql
--
-- إضافة جديدة فوق team_schema.sql اللي أصلاً متطبّق على السيرفر —
-- شغّله لوحده مرة واحدة. بيضيف عمودين لجدول public.students الموجود
-- (is_archived/archived_at) بدل جدول جديد، عشان "أرشفة الطالب" (بديل
-- الحذف النهائي) تتزامن بين المدرس والمساعدين في وضع الفريق زي باقي
-- بيانات الطالب بالظبط — راجع specs/002-student-archiving/data-model.md.

alter table public.students
  add column if not exists is_archived boolean not null default false,
  add column if not exists archived_at timestamptz;
