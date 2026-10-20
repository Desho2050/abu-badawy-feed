-- قسم «مواعيد قطارات مصر» يقرأ ملفًا مولَّدًا بدل جدول عناصر.
--
-- الجدول كله (35 قطارًا بمحطاتها وأوقاتها) ليس «عناصر» يحررها الناشر سطرًا سطرًا:
-- مصدره ورقة جدول الهيئة، وتفريقها في حقول عناصر منفصلة يفقد البنية التي يحتاجها
-- التطبيق — ترتيب الوقوف داخل الخط، والعدد بين محطتين، ووقت القيام لكل رحلة. لذا يُولَّد
-- الملف من الورقة بأداة في المستودع (tools/gen-trains-db.mjs) ويُرفَع إلى مستودع التغذية
-- كملف ثابت: data/trains/timetable.json.
--
-- لماذا لا يمسّه ناشر التغذية؟ لأن publish.mjs ينشر عناصر الأقسام التي items_source=admin
-- فقط (مرشَّح `managed` في الدالة الرئيسية، ويستثني تخطيطاتِ الكتالوج وحدها)،
-- ويطبع source.url لأي قسم json من feed_url إن وُجد
-- (الدالة sectionFileOf). فجعل القسم غيرَ مُدار وربطه بملفه يجعل index.json
-- يشير إلى الملف المولَّد، ويبقي جدولة النشر كل خمس دقائق بعيدًا عنه.
--
-- التطبيق يعرف الصيغة من layout='trains' فيجلب source.url كما هو (ContentSource.trains)
-- ولا يمرّه على قارئ التغذية؛ ومحرك البحث يعمل على الجهاز: محطة مغادرة ووصول، فيحسب
-- عدد الوقفات بينهما والمدة من ترتيب الطريق وأوقات الوقفات.
--
-- لا DDL هنا — لا قيد ولا عمود ولا جدول — لأن 'file' أصلًا ضمن items_source في
-- supabase-setup.sql، و'trains' وسّعه trains-section.sql. تحديثُ صفٍّ واحد فقط.
--
-- آمن للتكرار: UPDATE شرطي على id ثابت، فلا يكرّر صفًّا ولا يمسّ عناصر أحد.
-- نفّذه بعد trains-section.sql وبعد أن يكون الملف مرفوعًا إلى مستودع التغذية.
-- Supabase ← SQL Editor ← New query ← الصق ← Run (مشروع DeshoStore).

-- 1) التحديث: القسم يقرأ ملفه المولَّد.
update public.sections
   set subtitle     = 'ابحث عن موعد القطار بين محطتين: الوقت والمدة وعدد الوقفات',
       feed_url     = 'data/trains/timetable.json',
       items_source = 'file',
       source_kind  = 'json',
       note         = 'ملف القسم مولَّد من ورقة جدول الهيئة بأداة المستودع '
                   || 'tools/gen-trains-db.mjs؛ لا عناصر له في اللوحة. '
                   || 'حدِّث الورقة ثم انشر الملف، ولا تُرجع items_source=admin '
                   || 'إلا إذا قرّرت تحرير الرحلات عنصرًا عنصرًا.'
 where id = 'trains';

-- 2) تدقيق (قراءة فقط): WARNING عند النقص، NOTICE عند الجاهزية.
do $$
declare
  sec         public.sections%rowtype;
  kind_def    text;
  layout_def  text;
  live        integer;
begin
  select * into sec from public.sections where id = 'trains';

  if sec.id is null then
    raise warning 'WARNING: لا صف trains في sections — نفّذ trains-section.sql أولًا.';
    return;
  end if;

  -- أسماء القيود قد تختلف بين نسخة وأخرى، فالبحث بمحتواها أأمن.
  select string_agg(pg_get_constraintdef(c.oid), ' ') into kind_def
    from pg_constraint c
   where c.conrelid = 'public.sections'::regclass
     and c.conname ~ 'items_source';
  select string_agg(pg_get_constraintdef(c.oid), ' ') into layout_def
    from pg_constraint c
   where c.conrelid = 'public.sections'::regclass
     and c.conname ~ 'layout';

  if sec.items_source = 'file'
     and coalesce(sec.feed_url, '') = 'data/trains/timetable.json' then
    raise notice 'NOTICE: القسم موصول بملفه؛ يشير index.json إلى data/trains/timetable.json ولا يلمسه ناشر التغذية.';
  else
    raise warning 'WARNING: لم يُطبَّق التحديث؛ items_source=% وfeed_url=% — لن يُقرأ الجدول.',
      sec.items_source, coalesce(sec.feed_url, 'لا شيء');
  end if;

  if kind_def like '%file%' then
    raise notice 'NOTICE: قيد items_source قبِل file، فاللوحة تحفظ القسم بلا رفض.';
  else
    raise warning 'WARNING: قيد items_source لا يذكر file: %', coalesce(kind_def, 'لا قيد');
  end if;

  if layout_def like '%trains%' then
    raise notice 'NOTICE: قيد layout قبِل trains، فيُرسل publish.mjs التخطيط نفسه إلى التطبيق.';
  else
    raise warning 'WARNING: قيد layout لم يذكر trains — نفّذ trains-section.sql؛ وإلا رجع القسم list: %',
      coalesce(layout_def, 'لا قيد');
  end if;

  if sec.layout <> 'trains' or sec.source_kind <> 'json' then
    raise warning 'WARNING: التخطيط=% والمصدر=%؛ يُشترط trains/json ليعرف التطبيق أنه جدول لا تغذية.',
      sec.layout, sec.source_kind;
  else
    raise notice 'NOTICE: التخطيط trains والمصدر json، فيجلب التطبيق الملف بلا ترجمة إلى عناصر.';
  end if;

  if sec.enabled = false then
    raise warning 'WARNING: القسم مُعطَّل؛ فعّله من اللوحة ← الأقسام.';
  else
    raise notice 'NOTICE: القسم مُفعَّل؛ ترتيبه % ويظهر في الرئيسية=%.', sec.sort_order, sec.show_on_home;
  end if;

  -- عناصر بقيت من محاولة يدوية سابقة؟ لن تُنشر الآن، فالقسم لم يعد مُدارًا.
  select count(*) into live from public.items
   where section_id = 'trains' and status = 'published';
  if live > 0 then
    raise warning 'WARNING: % عنصر منشور في items لن تظهر؛ أرشفها، فقسم file لا يقرأ إلا ملفه.', live;
  else
    raise notice 'NOTICE: لا عناصر في items للقسم؛ الجدول كله في ملفه، فلا ازدواج مصدرين.';
  end if;
end $$;

-- 3) ما سيراه التطبيق في index.json بعد جولة النشر القادمة (قراءة فقط)
select id, title, subtitle, icon, layout, source_kind, feed_url, items_source,
       sort_order, enabled, show_on_home
  from public.sections
 order by sort_order;
