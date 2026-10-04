-- ثلاثة أقسام حيّة جديدة: مواقيت الصلاة، حالة الطقس، وآلة حاسبة للقياس.
-- لا عناصر لها في القاعدة — التطبيق يجلبها بنفسه من واجهات مفتوحة بلا مفاتيح:
--   prayer_times  ← api.aladhan.com (الهيئة المصرية العامة للمساحة، عصر شافعي)
--   weather       ← api.open-meteo.com + air-quality-api.open-meteo.com
--   converter     ← أسعار العملات المنشورة أصلًا + جداول وحدات داخل التطبيق
-- وكلها تُحسب من إحداثيات القرية، فتحتاج عمود location في app_settings.
--
-- آمن للتكرار (idempotent): يوسّع قيدين، ويضيف عمودًا، ويزكي ثلاثة صفوف.
-- نفّذه في Supabase ← SQL Editor ← New query ← الصق ← Run (مشروع DeshoStore).
-- ملاحظة: الأقسام تُحدَّث عناوينها وترتيبها في كل تشغيل، فإن أعدت تسميتها في
-- اللوحة فلا تعد تشغيل هذا الملف.

-- 1) القيود: أسماء القيود المولّدة تلقائيًا هي <table>_<column>_check
alter table public.sections drop constraint if exists sections_layout_check;
alter table public.sections add constraint sections_layout_check check (
  layout in ('richArticle','list','cards','profiles','offers','ads','rates','directory',
             'prayer','weather','converter')
);

alter table public.sections drop constraint if exists sections_source_kind_check;
alter table public.sections add constraint sections_source_kind_check check (
  source_kind in ('json','rss','html','fx','gold','inline','prayer','weather','converter')
);

-- 2) موقع القرية: كتلة jsonb واحدة، فلا هجرة بيانات عند إضافة حقل جديد
alter table public.app_settings add column if not exists location jsonb
  not null default '{}'::jsonb;

comment on column public.app_settings.location is
  '{name,latitude,longitude,timezone}: منه تُحسب مواقيت الصلاة وتُطلب الأرصاد. '
  'فارغ = يستخدم التطبيق موضع القرية الافتراضي (مركز بيلا، كفر الشيخ).';

-- ضبط لمرة واحدة فقط؛ وبعده يُعدَّل من اللوحة ← الإعدادات ← موقع القرية.
update public.app_settings
   set location = '{"name":"مركز بيلا، كفر الشيخ","latitude":31.1728,"longitude":31.2210,"timezone":"Africa/Cairo"}'::jsonb
 where id = 1 and location = '{}'::jsonb;

-- 3) الأقسام: بلا feed_url ولا عناصر، والتطبيق يعرف مصدرها من kind وحده
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, sort_order, enabled, show_on_home,
   notify_default, allow_breaking, note)
values
  ('prayer_times', 'مواقيت الصلاة', 'حسب موقع القرية وتوقيت المسجد', 'mosque', 'prayer', 'prayer', 5,
   true, true, false, false, 'يجلبها التطبيق من api.aladhan.com (method=5)، لا من اللوحة.'),
  ('weather', 'حالة الطقس', 'الآن والساعات القادمة وسبعة أيام', 'thermostat', 'weather', 'weather', 8,
   true, true, false, false, 'يجلبها التطبيق من api.open-meteo.com بنفس الإحداثيات.'),
  ('converter', 'آلة حاسبة للقياس', 'عملات وأطوال وأوزان ومساحات وحرارة وسرعات', 'calculate', 'converter', 'converter', 75,
   true, true, false, false, 'تحويلات العملات مبنية على أسعار العملات المنشورة.')
on conflict (id) do update
  set title       = excluded.title,
      subtitle    = excluded.subtitle,
      icon        = excluded.icon,
      layout      = excluded.layout,
      source_kind = excluded.source_kind,
      sort_order  = excluded.sort_order,
      note        = excluded.note;

-- 4) تحقّق مطبوع: نتائج في اللوح ورسائل في Running
do $$
declare
  live_sections integer;
  has_location  integer;
  place         jsonb;
  layout_def    text;
begin
  select count(*) into live_sections
    from public.sections
   where source_kind in ('prayer','weather','converter')
     and layout in ('prayer','weather','converter');

  select count(*) into has_location
    from information_schema.columns
   where table_schema = 'public' and table_name = 'app_settings' and column_name = 'location';

  select location into place from public.app_settings where id = 1;
  select pg_get_constraintdef(oid) into layout_def
    from pg_constraint where conname = 'sections_layout_check';

  if live_sections = 3 then
    raise notice 'NOTICE: الأقسام الحيّة الثلاثة جاهزة ومقيدة بصحيح التخطيط.';
  else
    raise warning 'WARNING: ناقص من الأقسام الحيّة (%) — توقّع قسمًا واحدًا لا يظهر في التطبيق.', 3 - live_sections;
  end if;

  if has_location = 1 then
    raise notice 'NOTICE: عمود location موجود، وقيمته الآن: %', coalesce(place::text, 'NULL');
  else
    raise warning 'WARNING: لا عمود location في app_settings — ستبقى المواقيت على موضع التطبيق الافتراضي.';
  end if;

  if layout_def like '%prayer%' then
    raise notice 'NOTICE: قيد layout قَبِل prayer/weather/converter.';
  else
    raise warning 'WARNING: قيد layout لم يُوسَّع: %', layout_def;
  end if;
end $$;

-- ما سينشره الناشر في index.json بعد جولة التشغيل القادمة (قراءة فقط)
select id, title, layout, source_kind, sort_order, enabled, show_on_home
  from public.sections
 where source_kind in ('prayer','weather','converter')
 order by sort_order;
