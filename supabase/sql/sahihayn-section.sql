-- قسم «صحيح البخاري ومسلم»: فهرسُ أسماءٍ على خادم القرية، والنصُّ عند صاحبه لا هنا.
--
-- لماذا ملفٌ مولّد لا عناصر لوحة؟ لأن المحتوى ليس أخبارًا: ٩٨ كتابًا في البخاري و٥٧ في
-- مسلم، وأرقامُ أحاديثٍ بجزيئات (٤٠٢.٢) ودرجاتٌ فارغة. حقنُ هذا في items سطرًا سطرًا يفقد
-- البنية التي تحتاجها الشاشة (أيُّ جمعٍ، وأيُّ كتابٍ، وما رقمُه في المصدر)، ويملأ اللوحة
-- بألوفِ صفوفَ لا يُحرَّر منها شيء. فالفاصلُ هو الفقرةُ نفسها التي جعلت «مواعيد قطارات مصر»
-- و«تحميل القرآن الكريم» و«مباريات اليوم» قسم file: publish.mjs يطبع source.url من feed_url
-- لأي قسم json (sectionFileOf)، وينشر عناصر items_source=admin فقط.
--
-- القياس لا الرواية (٢٠٢٦-١٠-٢٠، من هذا الجهاز):
--   * النصُّ من fawazahmed0/hadith-api على jsDelivr (رخصة Unlicense، بلا مفتاح، CORS مفتوحة):
--     editions/ara-bukhari/sections/<k>.json يردّ 200 لكل كتابٍ من ٠ إلى ٩٧، وara-muslim من ٠
--     إلى ٥٦. الملفُ الكامل للجمعِ واحدٌ يتجاوز ٥٫٧ ميجابايت، فالتحميلُ كتابًا كتابًا هو
--     القياس؛ والكتبُ أصغرُ من ٤٢٧ كيلوبايت.
--   * أسماء الكتب في المصدر إنجليزيةٌ خالصة («Revelation»، «Faith»)، ودرجاته [] دائمًا،
--     وفيه نصوصٌ فارغة (٩ في البخاري، ٢٠٣ في مسلم). لا يُختلَق اسمٌ عربيٌّ ولا حكمٌ: الأسماءُ
--     العربيةُ قِيست آليًّا مقابل ar.wikisource.org (list=apprefix، رخصة CC BY-SA 4.0) فبقي
--     ٤٦ من ٩٨ و٣١ من ٥٧ باسمٍ محقَّق، والباقي «الكتاب N» مع اسمِ المصدرِ الإنجليزي بجانبه.
--     ويكيبيديا العربيةُ نفسها لا تعدّد كتبَ الصحيحين، فلم تصلح مصدرًا للأسماء.
--   * لا إذن جديد: الجلبُ من التطبيق إلى jsDelivr مباشرةً، ولا خدمةً أمامية ولا تخزينًا
--     للنص على خادم القرية.
--
-- لا إعلانَ هنا ولا تنبيهات: آيةُ قرآنٍ وحديثُ نبِيٍّ لا يُقطَعان بلافتةِ شركة، و«عاجل» لا
-- يكون في سنةٍ ثابتة. ولا معاينةَ على الرئيسية: فهرسُ كتبٍ لا يزاحم أخبارَ القرية.
--
-- آمن للتكرار: يوسّع القيد ويزكّي صفَّ القسم وحده، ولا يمسّ قسمًا آخر ولا عنصرًا.
-- نفّذه في Supabase ← SQL Editor ← الصق ← Run (مشروع DeshoStore)، وارفع
-- web/data/hadith/titles.json إلى مستودع التغذية أولًا (node tools/gen-hadith-titles.mjs).

begin;

-- 1) قيد التخطيط: بلا توسيعه ترفض القاعدة حفظ القسم الجديد.
alter table public.sections drop constraint if exists sections_layout_check;
alter table public.sections add constraint sections_layout_check check (
  layout in ('richArticle','list','cards','profiles','offers','ads','rates','directory',
             'apps','channels','prayer','weather','converter','calendar','memorials','trains',
             'results','schedule','campaigns','quran','tasks','matches','hadith')
);

-- 2) القسم: ترتيبه ٩٧ — يجاور «تحميل القرآن الكريم» (٩٩) في ذيل القائمة، فالاثنان مكتبةُ
--    القرية لا نشرتها: من يفتح مصحفًا يفتح صحيحًا، ولا يزاحم الأسعارَ ولا الأخبار.
--    الأعلام كما في كل قسم file: show_on_home = false, notify_default = false,
--    allow_breaking = false, items_source = 'file'.
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, feed_url, sort_order, enabled,
   show_on_home, notify_default, allow_breaking, items_source, note)
values
  ('sahihayn', 'صحيح البخاري ومسلم',
   'كتبُ الصحيحين بأسمائها المحقَّقة، ونصُّ كلِّ كتابٍ من موزِّعه',
   'hadith', 'hadith', 'json', 'data/hadith/titles.json', 97,
   true, false, false, false, 'file',
   'النصُّ ليس على هذا الخادم ولا يُنسخ إليه: ملفُ data/hadith/titles.json الذي ولّدته '
   || 'tools/gen-hadith-titles.mjs يحمل فهرسَ أسماءِ الكتب فقط — عددُها ومدىُ أرقامها واسمُ '
   || 'المصدر الإنجليزي كما هو، والأسماءُ العربيةُ محقَّقةٌ مقابل ar.wikisource.org برخصة '
   || 'CC BY-SA 4.0 (٤٦ من ٩٨ في البخاري و٣١ من ٥٧ في مسلم؛ والبقيةُ «الكتاب N» لأن المصدرَ '
   || 'لا يعربها ولا نختلق له). نصُّ كلِّ حديثٍ يُقرأ من fawazahmed0/hadith-api على jsDelivr '
   || 'كتابًا كتابًا عند فتحه (رخصة Unlicense). لا درجاتٍ في المصدر (grades فارغة دائمًا) فلا '
   || 'حكمَ على حديثٍ في التطبيق، وفيه نصوصٌ فارغةٌ تُعرض بصورتها. لا تضف عنصرًا هنا فلن يُنشر: '
   || 'publish.mjs ينشر عناصر الأقسام التي items_source=admin فقط. للتحديث: شغّل المولِّد ثم '
   || 'ارفع web/data/hadith/titles.json؛ وللمعاينة: node tools/verify-hadith.mjs.')
on conflict (id) do update
  set title          = excluded.title,
      subtitle       = excluded.subtitle,
      icon           = excluded.icon,
      layout         = excluded.layout,
      source_kind    = excluded.source_kind,
      feed_url       = excluded.feed_url,
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

-- 4) تدقيق (قراءة فقط): WARNING عند خللٍ يمنع القسم، NOTICE عند السلامة.
do $$
declare
  layout_def text;
  sec        public.sections%rowtype;
  n_items    integer;
begin
  select pg_get_constraintdef(oid) into layout_def
    from pg_constraint where conname = 'sections_layout_check';
  select * into sec from public.sections where id = 'sahihayn';

  if layout_def like '%hadith%' then
    raise notice 'NOTICE: القيد قبِل hadith، فاللوحة تحفظ القسم بلا رفض.';
  else
    raise warning 'WARNING: لم يُوسَّع قيد التخطيط: %', coalesce(layout_def, 'لا قيد');
  end if;

  if sec.id is null then
    raise warning 'WARNING: لا صفّ sahihayn في sections — لن يظهر القسم في التطبيق.';
    return;
  end if;

  raise notice 'NOTICE: قسم الصحيحين جاهز: layout=%, icon=%, sort=%، على الرئيسية=%، تنبيه=%، مصدر=%، ملف=%',
    sec.layout, sec.icon, sec.sort_order, sec.show_on_home, sec.notify_default,
    sec.items_source, coalesce(sec.feed_url, 'لا شيء');

  if sec.items_source <> 'file' or coalesce(sec.feed_url, '') <> 'data/hadith/titles.json' then
    raise warning 'WARNING: القسم ليس fileً موصولًا بفهرسه (items_source=%, feed_url=%) — '
      'سينتظر عناصرَ لوحةٍ لا تأتي، فلن يرى التطبيق كتابًا واحدًا.',
      sec.items_source, coalesce(sec.feed_url, 'لا شيء');
  end if;

  -- الفهرسُ لا الخبر: لا معاينةَ رئيسيةً ولا «عاجل» في سنةٍ ثابتة.
  if sec.show_on_home then
    raise warning 'WARNING: القسم يظهر على الرئيسية؛ فهرسُ كتبٍ لا يزاحم أخبارَ القرية.';
  end if;
  if sec.notify_default or sec.allow_breaking then
    raise warning 'WARNING: تنبيهاتٌ مفعّلة (notify=%, breaking=%)؛ لا «عاجل» في حديثٍ منسوب.',
      sec.notify_default, sec.allow_breaking;
  end if;

  select count(*) into n_items from public.items
   where section_id = 'sahihayn' and status = 'published';
  if n_items > 0 then
    raise warning 'WARNING: % عنصرًا منشورًا في items للقسم؛ قسم file لا يقرأ إلا فهرسه. أرشفها.', n_items;
  else
    raise notice 'NOTICE: لا عناصر في items للقسم — الأسماءُ في فهرسنا والنصُّ عند الموزِّع.';
  end if;
end $$;

-- 5) ما سيراه التطبيق (قراءة فقط): صفّ القسم كما يُطبع في index.json.
select s.id, s.title, s.layout, s.icon, s.source_kind, s.feed_url, s.items_source,
       s.sort_order, s.enabled, s.show_on_home, s.notify_default, s.allow_breaking
  from public.sections s
 where s.id = 'sahihayn';
