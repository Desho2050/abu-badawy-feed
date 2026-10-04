-- صورة اختيارية لكل قسم: يرفعها الناشر من لوحة التحكم، فينشرها publish.mjs في
-- index.json باسم image، فيرسمها التطبيق في رأس شاشة القسم.
-- آمن للتكرار (idempotent): يضيف عمودًا واحدًا فقط ولا يمسّ أي بيانات.
-- نفّذه في Supabase ← SQL Editor ← New query ← الصق ← Run (مشروع DeshoStore).

alter table public.sections add column if not exists cover_image text;

comment on column public.sections.cover_image is
  'رابط صورة غلاف القسم (من مستودع media أو مسار نسبي). فارغ = بلا غلاف.';

-- تحقّق (قراءة فقط): صف واحد بالعمود ونوعه، وقسم به صورة إن كان قد رُفع واحدة.
select a.attname as column, format_type(a.atttypid, a.atttypmod) as type,
       (select count(*) from public.sections where cover_image is not null) as sections_with_cover
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relname = 'sections' and a.attname = 'cover_image';
