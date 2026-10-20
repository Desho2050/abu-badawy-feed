-- قسم «جدول مواعيد الامتحانات»: جداول المراحل التعليمية بموعدها، تُقرأ كما تُنشر رسميًا.
--
-- لماذا يدويًا؟ فُحص في ٢٠٢٦-١٠-١٩: لا JSON API واحد للجداول ولا مجموعة بيانات مفتوحة على
-- data.gov.eg أو moe.gov.eg. الجدول يصل خبرًا وصورةً وPDF: الثانوية العامة ٢٠٢٦ أعلنتها
-- الوزارة خبرًا (اليوم السابع ٢٠٢٦-٠٤-١٥)، والخريطة الزمنية ٢٠٢٦-٢٠٢٧ نُشرت بتاريخ الامتحانات
-- نصًّا (مصراوي ٢٠٢٦-٠٩-٠٩)، والإعدادية والدبلومات لكل محافظة جدولٌ من مديريتها، وللأزهر نظامٌ
-- مستقل. فمصدر الجدول هنا هو الإعلان نفسه، والرابط يبقى ظاهرًا في التطبيق.
--
-- بعكس قسم النتائج: الجدول الزمني معلومٌ عامّ لا بيانات قُصّر، فيمرّ بمسار items العادي
-- (لوحة ← Supabase ← Pages) بلا جدول جديد ولا دالة ولا مفتاح.
--
-- البيانات المُدخلة الآن هي ما تقوله الوزارة بحرفيته: فتراتٌ لا جلسات بمادة ووقت، لأن الجدول
-- التفصيلي لكل مادة يخرج من كل مديرية/إدارة لاحقًا. تواريخها متقاطعة مع التقويم: السبت ٩ يناير
-- ٢٠٢٧ = السبت فعلًا، والخميس ١٤ يناير، والسبت ١٦ إلى الخميس ٢١ يناير، والسبت ٢٦ يونيو إلى
-- الأربعاء ٢١ يوليو ٢٠٢٧ — والمصدر نفسه يقول أن العام بدأ السبت ١٢ سبتمبر ٢٠٢٦ وانتهى الترم
-- الأول الخميس ٣١ ديسمبر ويبدأ الثاني السبت ٦ فبراير ٢٠٢٧. خمسة مواضع من الخبر تطابق التقويم،
-- فليس هنا تاريخٌ من اختلاق.
--
-- آمن للتكرار: يوسّع القيد، ويزكّي صفّ القسم وثلاثة عناصر بسلاسلها، ولا يمسّ غيرها.
-- نفّذه في Supabase ← SQL Editor ← الصق ← Run (مشروع DeshoStore)، ثم workflow_dispatch.

begin;

-- 1) قيد التخطيط: بلا توسيعه ترفض القاعدة حفظ القسم الجديد.
alter table public.sections drop constraint if exists sections_layout_check;
alter table public.sections add constraint sections_layout_check check (
  layout in ('richArticle','list','cards','profiles','offers','ads','rates','directory',
             'apps','channels','prayer','weather','converter','calendar','memorials','trains',
             'results','schedule','campaigns','quran','tasks','matches','hadith')
);

-- 2) القسم: ترتيبه ٨٧ يلي النتائج (٨٦) — خدمةٌ واحدة لطالبٍ واحد: الجدول أولًا ثم النتيجة.
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, sort_order, enabled, show_on_home,
   notify_default, allow_breaking, items_source, note)
values
  ('exam_schedule', 'جدول مواعيد الامتحانات',
   'مواعيد امتحانات كل مرحلة كما تعلنها الجهة الرسمية',
   'calendar', 'schedule', 'json', 87,
   true, false, false, true, 'admin',
   'كل عنصر جلسةٌ أو فترة: العنوان اسم المادة أو الفترة، وفي الحقول الإضافية: المرحلة، '
   || 'التاريخ، النهاية، الوقت، المدة، الشعبة، الدور، اللجنة، ملاحظات. التاريخ بصيغة 2027-01-09 '
   || '(أرقامٌ عربية مقبولة كما تُنسخ)، والوقت 09:00 أو «٩ ص». بلا «التاريخ» ينزل العنصر في '
   || '«مواعيد لم تُحدَّد بعد» — فلا يُختلق موعد. «رابط خارجي» = صفحة الجدول الرسمي.')
on conflict (id) do update
  set title        = excluded.title,
      subtitle     = excluded.subtitle,
      icon         = excluded.icon,
      layout       = excluded.layout,
      source_kind  = excluded.source_kind,
      sort_order   = excluded.sort_order,
      enabled      = excluded.enabled,
      show_on_home = excluded.show_on_home,
      notify_default = excluded.notify_default,
      allow_breaking = excluded.allow_breaking,
      items_source = excluded.items_source,
      note         = excluded.note;

-- 3) عناصر الخريطة الزمنية ٢٠٢٦-٢٠٢٧: تُحذف بسلاسلها ثم تُدخل، فيبقى التنفيذ قابلًا للتكرار.
delete from public.items
 where section_id = 'exam_schedule'
   and slug in ('term1-transfer-2027', 'term1-preparatory-2027', 'secondary-first-2027');

insert into public.items
  (section_id, slug, title, subtitle, body, link, source_name, source_url,
   fields, status, sort_order, published_at, event_date)
values
  ('exam_schedule', 'term1-transfer-2027',
   'امتحانات الفصل الدراسي الأول — صفوف النقل',
   'من السبت ٩ يناير إلى الخميس ١٤ يناير ٢٠٢٧',
   'المدة كما أعلنتها الوزارة في الخريطة الزمنية للعام الدراسي ٢٠٢٦-٢٠٢٧. الجدول التفصيلي '
   || 'بالمواد والمواعيد اليومية تصدره كل إدارة تعليمية لصفوف النقل قبلها بأسابيع.',
   'https://www.masrawy.com/news/education-schooleducation/details/2026/9/9/3045420',
   'وزارة التربية والتعليم — الخريطة الزمنية',
   'https://www.masrawy.com/news/education-schooleducation/details/2026/9/9/3045420',
   '{"المرحلة":"صفوف النقل","التاريخ":"2027-01-09","النهاية":"2027-01-14","الدور":"الفصل الدراسي الأول","ملاحظات":"الجدول التفصيلي من الإدارة التعليمية"}'::jsonb,
   'published', 30, '2026-09-09', '2027-01-09'),

  ('exam_schedule', 'term1-preparatory-2027',
   'امتحانات الشهادة الإعدادية — الفصل الدراسي الأول',
   'من السبت ١٦ يناير إلى الخميس ٢١ يناير ٢٠٢٧',
   'المدة كما أعلنتها الوزارة. الجدول بكل محافظة تُصدره مديريتها، فيُنشر هنا مفصلًا حين يصدر.',
   'https://www.masrawy.com/news/education-schooleducation/details/2026/9/9/3045420',
   'وزارة التربية والتعليم — الخريطة الزمنية',
   'https://www.masrawy.com/news/education-schooleducation/details/2026/9/9/3045420',
   '{"المرحلة":"الشهادة الإعدادية","التاريخ":"2027-01-16","النهاية":"2027-01-21","الدور":"الفصل الدراسي الأول","ملاحظات":"الجدول التفصيلي من مديرية كل محافظة"}'::jsonb,
   'published', 20, '2026-09-09', '2027-01-16'),

  ('exam_schedule', 'secondary-first-2027',
   'امتحانات الثانوية العامة — الدور الأول',
   'من السبت ٢٦ يونيو إلى الأربعاء ٢١ يوليو ٢٠٢٧',
   'المدة من الخريطة الزمنية للعام ٢٠٢٦-٢٠٢٧. جدول المواد لكل شعبة (علمي/أدبي) يُعلن لاحقًا '
   || 'من الوزارة، فيُستبدل هذا العنصر بجلساته التفصيلية.',
   'https://www.masrawy.com/news/education-schooleducation/details/2026/9/9/3045420',
   'وزارة التربية والتعليم — الخريطة الزمنية',
   'https://www.masrawy.com/news/education-schooleducation/details/2026/9/9/3045420',
   '{"المرحلة":"الثانوية العامة","التاريخ":"2027-06-26","النهاية":"2027-07-21","الدور":"الدور الأول","ملاحظات":"جدول المواد لكل شعبة يصدر لاحقًا"}'::jsonb,
   'published', 10, '2026-09-09', '2027-06-26');

-- 4) لا يلتقط PostgREST الجدول الجديد حتى تُحمَّل خطته.
select pg_notify('pgrst', 'reload schema');

commit;

-- 5) تدقيق (قراءة فقط): WARNING عند خللٍ يمنع القسم، NOTICE عند السلامة.
do $$
declare
  layout_def text;
  sec        public.sections%rowtype;
  n_items    integer;
  n_dated    integer;
  n_staged   integer;
begin
  select pg_get_constraintdef(oid) into layout_def
    from pg_constraint where conname = 'sections_layout_check';
  select * into sec from public.sections where id = 'exam_schedule';
  select count(*) into n_items from public.items where section_id = 'exam_schedule' and status = 'published';
  select count(*) into n_dated from public.items
    where section_id = 'exam_schedule' and status = 'published'
      and coalesce(fields->>'التاريخ', '') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';
  select count(*) into n_staged from public.items
    where section_id = 'exam_schedule' and status = 'published' and btrim(coalesce(fields->>'المرحلة','')) <> '';

  if layout_def like '%schedule%' then
    raise notice 'NOTICE: القيد قبِل schedule، فاللوحة تحفظ القسم بلا رفض.';
  else
    raise warning 'WARNING: لم يُوسَّع قيد التخطيط: %', coalesce(layout_def, 'لا قيد');
  end if;

  if sec.id is null then
    raise warning 'WARNING: لا صف exam_schedule في sections — لن يظهر القسم في التطبيق.';
  else
    raise notice 'NOTICE: قسم الجداول جاهز: layout=%, icon=%, sort=%, على الرئيسية=%',
      sec.layout, sec.icon, sec.sort_order, sec.show_on_home;
  end if;

  if sec.show_on_home then
    raise warning 'WARNING: القسم يظهر على الصفحة الرئيسية؛ جداول الامتحانات تزاحم أخبار القرية.';
  end if;

  if n_items = 3 and n_dated = 3 and n_staged = 3 then
    raise notice 'NOTICE: ثلاثة عناصر منشورة، لها مرحلة وتاريخ يُقرآن؛ شغّل node tools/verify-schedule.mjs.';
  else
    raise warning 'WARNING: عناصر القسم (% منشور، % بتاريخ مفهوم، % بمرحلة) — المِشْبَك سيحذّر.',
      n_items, n_dated, n_staged;
  end if;
end $$;

-- 6) ما سيراه التطبيق (قراءة فقط): المواعيد بالترتيب الذي ستجمعه الشاشة.
select fields->>'المرحلة' as مرحلة,
       fields->>'التاريخ' as بداية,
       coalesce(fields->>'النهاية', '—') as نهاية,
       coalesce(fields->>'الدور', '—') as دور,
       title
  from public.items
 where section_id = 'exam_schedule' and status = 'published'
 order by fields->>'التاريخ';
