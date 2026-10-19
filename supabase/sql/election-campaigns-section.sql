-- قسم «الحملات الانتخابية»: إعلانات المرشحين كما تُعلنها حملاتُها، لا كما يصفها التطبيق.
--
-- لماذا يُنشر فارغًا؟ فُحص في ٢٠٢٦-١٠-٢٠: لا جدول زمني منشور لانتخابات قادمة على موقع
-- الهيئة الوطنية للانتخابات (elections.eg) — آخرُه مجلس النواب ٢٠٢٥، ولا مصدر آليّ لبيانات
-- المرشحين في دائرة كفر الشيخ. فاسمُ المرشح ورقمُه ورمزُه ومقرُّه يُنسخ عن منشور حملته هو،
-- ويصل إلى اللوحة حين يصل. مرشّحٌ مختلقٌ برقمٍ مختلق هنا ليس «بيانات ثابتة» بل معلومةٌ
-- سياسيةٌ كاذبة يقرؤها أهلُ القرية، فلا يُزرع في هذا الملف عنصرٌ واحد.
--
-- العنصر بعشرَةِ حقولٍ لا تزيد: الانتخابات، الدائرة، النظام، رقم المرشح، الرمز، المقر،
-- الفعالية، التاريخ، الوقت، تنتهي. والسقفُ عقدٌ لا نصيحة: publish.mjs يقطع fields عند عشرةٍ
-- وjsonb لا يحفظ ترتيب المفاتيح، فالحادي عشر يسقط صامتًا لا يرفع خطأ. الإعلان المدفوع وسمٌ
-- («إعلان مدفوع») لا حقل، لأن المفاتيح ممتلئة.
--
-- آمن للتكرار: يوسّع القيد ويزكّي صفّ القسم وحده، ولا يمسّ قسمًا آخر ولا عنصرًا.
-- نفّذه في Supabase ← SQL Editor ← الصق ← Run (مشروع DeshoStore)، ثم workflow_dispatch.

begin;

-- 1) قيد التخطيط: بلا توسيعه ترفض القاعدة حفظ القسم الجديد.
alter table public.sections drop constraint if exists sections_layout_check;
alter table public.sections add constraint sections_layout_check check (
  layout in ('richArticle','list','cards','profiles','offers','ads','rates','directory',
             'apps','channels','prayer','weather','converter','calendar','memorials','trains',
             'results','schedule','campaigns')
);

-- 2) القسم: ترتيبه ٩٨ — بعد التطبيقات والقنوات وقبل «إعلانات القرية» (١٠٠): إعلاناتٌ هي،
--    لكن بمقامٍ أعلى حساسية، فلا يُزاحم أخبارَ القرية على الرئيسية ولا يُرسَل عنه تنبيه.
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, sort_order, enabled, show_on_home,
   notify_default, allow_breaking, items_source, note)
values
  ('election_campaigns', 'الحملات الانتخابية',
   'إعلانات المرشحين كما تنشرها حملاتُها، باسم الاستحقاق ودائرته',
   'voting', 'campaigns', 'json', 98,
   true, false, false, true, 'admin',
   'العنوان اسمُ المرشح كما يوقّع حملته، والسطر التعريفي شعارها أو صفته، والصورة ملصقها. '
   || 'الحقول عشرةٌ لا تزيد: الانتخابات، الدائرة، النظام، رقم المرشح، الرمز، المقر، الفعالية، '
   || 'التاريخ، الوقت، تنتهي. التاريخ يومُ الفعالية 2026-11-03 والوقت 19:00 أو «٧ م» وتنتهي '
   || 'آخرُ يومٍ يبقى الإعلان ساريًا؛ فما تجاوزه يطويه التطبيق في «انتهت» ولا يحذفه. '
   || '«اسم المصدر» الجهة ناشرة الإعلان — ولا يُنشر إعلانٌ بلا مصدر. الإعلان المدفوع وسم '
   || '«إعلان مدفوع» في الوسوم، لا حقلٌ في الحقول العشرة.')
on conflict (id) do update
  set title          = excluded.title,
      subtitle       = excluded.subtitle,
      icon           = excluded.icon,
      layout         = excluded.layout,
      source_kind    = excluded.source_kind,
      sort_order     = excluded.sort_order,
      enabled        = excluded.enabled,
      show_on_home   = excluded.show_on_home,
      notify_default = excluded.notify_default,
      allow_breaking = excluded.allow_breaking,
      items_source   = excluded.items_source,
      note           = excluded.note;

-- 3) لا يلتقط PostgREST الجدول الجديد حتى تُحمَّل خطته.
select pg_notify('pgrst', 'reload schema');

commit;

-- 4) تدقيق (قراءة فقط): WARNING عند خللٍ يمنع القسم أو يخالف شرطه، NOTICE عند السلامة.
do $$
declare
  layout_def    text;
  sec           public.sections%rowtype;
  n_items       integer;
  n_no_source   integer;
  n_no_election integer;
  n_no_end      integer;
  n_over_cap    integer;
begin
  select pg_get_constraintdef(oid) into layout_def
    from pg_constraint where conname = 'sections_layout_check';
  select * into sec from public.sections where id = 'election_campaigns';

  select count(*) into n_items from public.items
   where section_id = 'election_campaigns' and status = 'published';
  select count(*) into n_no_source from public.items
   where section_id = 'election_campaigns' and status = 'published'
     and coalesce(btrim(source_name), '') = '' and coalesce(btrim(source_url), '') = '';
  select count(*) into n_no_election from public.items
   where section_id = 'election_campaigns' and status = 'published'
     and coalesce(btrim(fields->>'الانتخابات'), '') = '';
  select count(*) into n_no_end from public.items
   where section_id = 'election_campaigns' and status = 'published'
     and coalesce(btrim(fields->>'تنتهي'), '') = '';
  select count(*) into n_over_cap from public.items i
   where i.section_id = 'election_campaigns' and i.status = 'published'
     and (select count(*) from jsonb_object_keys(i.fields)) > 10;

  if layout_def like '%campaigns%' then
    raise notice 'NOTICE: القيد قبِل campaigns، فاللوحة تحفظ القسم بلا رفض.';
  else
    raise warning 'WARNING: لم يُوسَّع قيد التخطيط: %', coalesce(layout_def, 'لا قيد');
  end if;

  if sec.id is null then
    raise warning 'WARNING: لا صفّ election_campaigns في sections — لن يظهر القسم في التطبيق.';
  else
    raise notice 'NOTICE: قسم الحملات جاهز: layout=%, icon=%, sort=%, على الرئيسية=%، تنبيه=%',
      sec.layout, sec.icon, sec.sort_order, sec.show_on_home, sec.notify_default;
  end if;

  if sec.show_on_home then
    raise warning 'WARNING: القسم يظهر على الرئيسية؛ الحملة لا تزاحم أخبار القرية.';
  end if;
  if sec.notify_default then
    raise warning 'WARNING: notify_default=true؛ التنبيه يُرسَل تلقائيًّا عن حملةٍ مرشّحة.';
  end if;

  if n_items = 0 then
    raise notice 'NOTICE: لا إعلان منشور — كما تقرّر الملف: اللوحة تملؤه بما يأتيها من الحملات.';
  else
    if n_no_source > 0 then
      raise warning 'WARNING: % إعلانٌ بلا مصدر؛ التطبيق لا يعرف المرشح من رأيه.', n_no_source;
    end if;
    if n_no_election > 0 then
      raise warning 'WARNING: % إعلانٌ بلا حقل «الانتخابات»؛ لا تُبنى رقاقةُ التصفية.', n_no_election;
    end if;
    if n_no_end > 0 then
      raise warning 'WARNING: % إعلانٌ بلا «تنتهي»؛ لن يُطوى حين تنتهي الحملة فيبدو جارية.', n_no_end;
    end if;
    if n_over_cap > 0 then
      raise warning 'WARNING: % إعلانٌ بأكثر من عشرة حقول؛ النشر يقطعها صامتًا.', n_over_cap;
    end if;
    raise notice 'NOTICE: % إعلانٌ منشور؛ شغّل node tools/verify-campaigns.mjs.', n_items;
  end if;
end $$;

-- 5) ما سيراه التطبيق (قراءة فقط): صفّ القسم، وعدد إعلاناته، وعناوينها كما تُقرأ.
select s.id, s.layout, s.icon, s.sort_order, s.show_on_home,
       (select count(*) from public.items i
         where i.section_id = s.id and i.status = 'published') as ads,
       (select coalesce(string_agg(i.title, ' | ' order by i.sort_order), '— لا إعلان منشور —')
          from public.items i
         where i.section_id = s.id and i.status = 'published') as titles
  from public.sections s
 where s.id = 'election_campaigns';
