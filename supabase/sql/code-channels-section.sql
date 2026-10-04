-- قسم «قنوات تعليم البرمجة للأطفال»: روابط قنوات عربية تعلّم البرمجة للصغار
-- بأسلوب سهل (سكراتش، أساسيات الكمبيوتر، روبوتكس، مسارات مبتدئة).
--
-- العناصر تُدار من اللوحة (العناصر ← جديد ← القسم: قنوات البرمجة) كأي قسم محتوى،
-- والتطبيق يرسمها ببطاقة خاصة: شعار القناة أو رمز دائري بدلًا منه، وشارة المنصة،
-- والوصف، ووسوم المواضيع، وزر «افتح القناة على يوتيوب» يرسل الرابط إلى نظام
-- التشغيل (بلا أذونات جديدة، وبلا WebView، وبلا أي تتبّع).
--
-- متفق مع اللوحة والتطبيق في ثلاث اصطلاحات داخل العنصر:
--   الصورة      ← شعار القناة (مربعة؛ اتركها فارغًا فيرسم التطبيق رمزًا)
--   رابط خارجي  ← صفحة القناة على يوتيوب، وهو ما يفتحه الزر
--   الوسوم      ← مواضيع القناة؛ أو حقل «المواضيع» بسطر واحد تفصل الفواصل قيمه
--
-- الروابط الستة هنا مُتحقق منها بالفتح في 2026-10-04: كل واحد رجع HTTP 200
-- وعنوان القناة مطابقًا، ومعها معرّف القناة UC… في الحقول، فلو تغيّر الاسم
-- المستعار (@handle) بقي المعرّف طريقًا لتحديث الرابط.
--
-- آمن للتكرار (idempotent): يوسّع قيد layout، وينشئ القسم أو يحدّثه مع ستة عناصر.
-- نفّذه في Supabase ← SQL Editor ← New query ← الصق ← Run (مشروع DeshoStore).
-- يوسّع قيد التخطيط ليشمل channels مع الأسماء كلها، فيحلّ محل tools/my-apps-section.sql
-- وtools/calendar-section.sql في القيد وحده؛ أمّا قسماهما فيبقيان بحاجة تشغيل ملفيهما.

-- 1) قيد التخطيط: بلا توسيعه ترفض القاعدة حفظ القسم الجديد.
alter table public.sections drop constraint if exists sections_layout_check;
alter table public.sections add constraint sections_layout_check check (
  layout in ('richArticle','list','cards','profiles','offers','ads','rates','directory',
             'apps','channels','prayer','weather','converter','calendar')
);

-- 2) القسم: مصدره json وعناصره من اللوحة، فيكتب الناشر ملفه في الجولة القادمة.
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, sort_order, enabled, show_on_home,
   notify_default, allow_breaking, items_source, note)
values
  ('code_channels', 'قنوات البرمجة',
   'روابط قنوات عربية تعلّم الأطفال البرمجة بأسهل طريقة', 'channels', 'channels', 'json', 96,
   true, true, false, false, 'admin',
   'كل قناة عنصر هنا: «رابط خارجي» هو صفحة القناة، والوسوم مواضيعها. تحقق من أي رابط جديد بفتحه قبل النشر.')
on conflict (id) do update
  set title       = excluded.title,
      subtitle    = excluded.subtitle,
      icon        = excluded.icon,
      layout      = excluded.layout,
      source_kind = excluded.source_kind,
      sort_order  = excluded.sort_order,
      note        = excluded.note;

-- 3) البذور: قناة لكل عنصر منشور. التكرار لا يزدوجها (where not exists بالslug)،
--    فاحذف ما لا تريد من اللوحة بدل التعديل هنا.
insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'code_channels', 'junior-coders',
  'جنيور كودرز — Junior Coders',
  'برمجة للأطفال بطريقة سهلة وسلسة، مع أنشطة تُعمل في البيت',
  '<p>قناة تشرح أساسيات البرمجة للأطفال بأسلوب مبسّط، وهدفها مساعدة الأهل على شرح البرمجة '
    || 'لأبنائهم مع إتاحة متابعة الطفل للفيديوهات بنفسه. فيها قائمة «Programming for kids '
    || '(Hour of code)» للأنشطة الرقمية، وقائمة «Unplugged Programming activities for kids» '
    || 'أنشطة برمجة بلا شاشة تُنفَّذ بالورقة والقلم.</p>',
  null, 'https://www.youtube.com/@TheHend1986', 'يوتيوب', 'https://www.youtube.com/@TheHend1986',
  '["أنشطة بلا شاشة", "ساعة البرمجة", "مع الأهل"]'::jsonb,
  '{"اللغة": "العربية", "الفئة العمرية": "الأطفال مع الأهل", "معرّف القناة": "UC4hlEHtJ2sBwTSBqt5-ZayA"}'::jsonb,
  'published', 60, now()
where not exists (select 1 from public.items where section_id = 'code_channels' and slug = 'junior-coders');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'code_channels', 'safaa-elshafey',
  'برمجة للأطفال — صفاء الشافعي',
  'كورسات سكراتش وأساسيات الكمبيوتر بالعربي من الصفر',
  '<p>قناة متخصصة في تعليم البرمجة في سن مبكرة، تشرح من الصفر بأسلوب مبسّط. يقسَّم محتواها '
    || 'إلى مسارات معلومة العمر، منها «أساسيات الكمبيوتر» من السادسة إلى السادسة عشرة، ومسار '
    || '«The Journeys» من الثامنة إلى السادسة عشرة في أساسيات الويب، إلى جانب دروس سكراتش بالعربي.</p>',
  null, 'https://www.youtube.com/@SafaaElShafey', 'يوتيوب', 'https://www.youtube.com/@SafaaElShafey',
  '["سكراتش", "أساسيات الكمبيوتر", "ويب للمبتدئين"]'::jsonb,
  '{"اللغة": "العربية", "الفئة العمرية": "من ٦ إلى ١٦ سنة", "معرّف القناة": "UCC_bGf8JdzCef1ubGK8yYyA"}'::jsonb,
  'published', 50, now()
where not exists (select 1 from public.items where section_id = 'code_channels' and slug = 'safaa-elshafey');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'code_channels', 'little-coder',
  'ليتل كودر — Little Coder',
  '«علّموا أولادكم البرمجة»: دروس ومشاريع للأطفال بالعربي',
  '<p>قناة تنطلق من أن البرمجة صارت لغة أساسية تدخل المناهج، فتعلّم الأطفال خطوة خطوة '
    || 'بمشاريع صغيرة، وتقدّم أيضًا محتوى لإعداد مدرّبي برمجة للأطفال — ما يجعلها مفيدة '
    || 'للأهل والمعلّمين الذين يريدون ورشة صيفية في القرية.</p>',
  null, 'https://www.youtube.com/@LittleCoder', 'يوتيوب', 'https://www.youtube.com/@LittleCoder',
  '["مشاريع للأطفال", "سكراتش", "إعداد مدرّبين"]'::jsonb,
  '{"اللغة": "العربية", "الفئة العمرية": "الأطفال", "معرّف القناة": "UCK4EAMITJEmO0lgEMdy8EYw"}'::jsonb,
  'published', 40, now()
where not exists (select 1 from public.items where section_id = 'code_channels' and slug = 'little-coder');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'code_channels', 'samar-kids-camp',
  'سامار كيدز كامب — SAMAR KIDS CAMP',
  'كورس سكراتش للأطفال بالعربي مع أنشطة تعليمية عامة',
  '<p>قناة تستهدف تعليم الأطفال في جوانب دينية وأخلاقية وتعليمية معًا، ومنها كورس سكراتش '
    || 'بالعربي بمقدمة مبسّطة للصغار. تصلح لمن يريد محتوى طفوليًّا خفيفًا لا برمجة وحدها.</p>',
  null, 'https://www.youtube.com/@samarsamy1145', 'يوتيوب', 'https://www.youtube.com/@samarsamy1145',
  '["سكراتش", "أنشطة للأطفال", "تعليم عام"]'::jsonb,
  '{"اللغة": "العربية", "الفئة العمرية": "الأطفال", "معرّف القناة": "UCjqlJ986W6jJzIcUK3CMhjA"}'::jsonb,
  'published', 30, now()
where not exists (select 1 from public.items where section_id = 'code_channels' and slug = 'samar-kids-camp');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'code_channels', 'robotics-for-kids',
  'روبوتكس للأطفال — Robotics for kids',
  'من البرمجة إلى صناعة الروبوت: أساسيات للأطفال والمبتدئين',
  '<p>قناة متخصصة بعلوم الروبوت، تساعد الأطفال والمبتدئين على تعلّم أساسيات صناعة الروبوت '
    || 'خطوة خطوة. وهي الأنسب لمن أنهى أساسيات سكراتش وأراد الانتقال إلى أجهزة حقيقية '
    || 'وبرمجة الحركة والحسّاسات.</p>',
  null, 'https://www.youtube.com/@roboticsforkids2023', 'يوتيوب', 'https://www.youtube.com/@roboticsforkids2023',
  '["روبوتكس", "إلكترونيات", "برمجة الأجهزة"]'::jsonb,
  '{"اللغة": "العربية", "الفئة العمرية": "الأطفال والمبتدئون", "معرّف القناة": "UCtoPvUaO2fix6Rzdvu5GUnQ"}'::jsonb,
  'published', 20, now()
where not exists (select 1 from public.items where section_id = 'code_channels' and slug = 'robotics-for-kids');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'code_channels', 'almdrasa',
  'المدرسة — Almdrasa',
  'مسارات تعلّم البرمجة بالعربية للناشئة والمبتدئين',
  '<p>قناة متخصصة في تعليم البرمجة بالعربية، فيها مسارات طويلة تبدأ من الصفر، ومنها ترجمة '
    || 'عربية لمحتوى CS50 وسكربتشي كمقدمة في التفكير البرمجي. محتواها موجَّه للناشئة والكبار '
    || 'أكثر منه للصغار، فيناسب طالبًا في ثانوي يريد مسارًا منظمًا.</p>',
  null, 'https://www.youtube.com/@AlmdrasaLTD', 'يوتيوب', 'https://www.youtube.com/@AlmdrasaLTD',
  '["مسارات تعلّم", "CS50 بالعربي", "سكراتش"]'::jsonb,
  '{"اللغة": "العربية", "الفئة العمرية": "الناشئة والمبتدئون", "معرّف القناة": "UCSy7Y-SWLNCAX2AcpNuRHRg"}'::jsonb,
  'published', 10, now()
where not exists (select 1 from public.items where section_id = 'code_channels' and slug = 'almdrasa');

-- 4) تحقّق مطبوع: نتائج في اللوح ورسائل في Running.
do $$
declare
  sect       record;
  seeded     integer;
  broken     integer;
  layout_def text;
begin
  select layout, source_kind, items_source into sect
    from public.sections where id = 'code_channels';

  if not found then
    raise warning 'WARNING: قسم code_channels غير موجود — لن يظهر في درج التطبيق.';
  else
    raise notice 'NOTICE: قسم قنوات البرمجة جاهز (layout=%, kind=%, items=%).',
      sect.layout, sect.source_kind, sect.items_source;
  end if;

  select count(*) into seeded from public.items
   where section_id = 'code_channels' and status = 'published';

  if seeded >= 6 then
    raise notice 'NOTICE: % عناصر منشورة في القسم، والناشر يكتبها في data/sections/code_channels.json.', seeded;
  else
    raise warning 'WARNING: عناصر القسم المنشورة % فقط (المتوقع ٦) — أعد تشغيل الملف أو أضف البقية من اللوحة.', seeded;
  end if;

  select count(*) into broken from public.items
   where section_id = 'code_channels'
     and coalesce(link, '') !~* '^https://www\.youtube\.com/@';

  if broken > 0 then
    raise warning 'WARNING: % عنصرًا رابطه ليس صفحة قناة على يوتيوب — راجعه قبل النشر.', broken;
  else
    raise notice 'NOTICE: كل الروابط بصيغة صفحة قناة على يوتيوب.';
  end if;

  select pg_get_constraintdef(oid) into layout_def
    from pg_constraint where conname = 'sections_layout_check';
  if layout_def like '%channels%' then
    raise notice 'NOTICE: قيد layout قَبِل channels.';
  else
    raise warning 'WARNING: قيد layout لم يُوسَّع: %', layout_def;
  end if;
end $$;

-- ما سينشره الناشر في index.json و data/sections/code_channels.json (قراءة فقط)
select i.slug, i.title, i.link,
       i.tags ->> 0          as first_topic,
       i.fields ->> 'الفئة العمرية' as ages,
       i.status
  from public.items i
 where i.section_id = 'code_channels'
 order by i.sort_order desc;
