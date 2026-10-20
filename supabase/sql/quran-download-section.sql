-- قسم «تحميل القرآن الكريم»: تلاوات يُنزلها المستخدم من موزّعها العام، لا عناصرُ قرية.
--
-- لماذا ملفٌ مولّد لا عناصر لوحة؟ لأن المحتوى ليس أخبارًا: 288 مصحفًا (٢٤٢ قارئًا في ٢٠
-- رواية) لكلٍّ خادمٌ وأسلوبُ تلاوةٍ وقائمةُ سورٍ موجودة — وحقنةُ هذا في جدول items سطرًا
-- سطرًا تفقد البنية التي يحتاجها التطبيق (أيُّ روايةٍ لأيِّ قارئ، وأيُّ سورةٍ في أيِّ مصحف)،
-- وتملأ اللوحة بـ 288 صفًا لا يُحرَّر منها شيء. فالفقرة التي جعلت «مواعيد قطارات مصر» قسم
-- file (trains-timetable-file.sql) هي نفسها هنا: publish.mjs يطبع source.url من feed_url
-- لأي قسم json (sectionFileOf، السطر 568)، وينشر عناصر items_source=admin فقط (السطر 781)،
-- فجعلُ القسم file وربطُه بملفه يُبقي جدولة النشر كلَّ خمس دقائق بعيدًا عنه.
--
-- القياس لا الرواية (٢٠٢٦-١٠-٢٠، من هذا الجهاز): واجهة mp3quran.net العامة للمطوّرين
-- (suwar/riwayat/reciters) ترد 200، ومسارات التلاوات على cdn.mp3quran.net بـ https وترد
-- Accept-Ranges: bytes مع 206 لمقطع 64KB في 0.73s، وسورةٌ 3.5MB نُزّلت في 2.35s (1.51MB/s).
-- ومصحفٌ كاملٌ عند معيقلي r1 = 676MB (البقرة وحدها 49.5MB) — فالتنزيل سورةً سورة، ولا زرَّ
-- «نزّل كل شيء». وقائمةُ السور الثابتة (114 سورة، 6236 آية، 86 مكّية) مولَّدةٌ من مصدرين
-- يتقاطعان: mp3quran للأسماء العربية وapi.alquran.cloud للأعداد، بأمر
-- tools/gen-quran-surahs.mjs داخل التطبيق.
--
-- لا صوتَ هنا ولا نصَّ قرآن: الملف الكتالوجُ فقط — أسماءٌ وأرقامٌ وروابطُ خادم. والتلاوةُ
-- تُنزَّل إلى مجلد التطبيق على ذاكرة الجهاز عند نقرِ المستخدم صراحةً، بغير إذنٍ واحد جديد،
-- والموزَّع مسمّى في الشاشة. ولا عناصرَ مُذرَعة: لا في هذا الملف ولا اختباره — فلا يُنشر
-- قرآنٌ وهمي على تغذية القرية.
--
-- آمن للتكرار: يوسّع القيد ويزكّي صفَّ القسم وحده، ولا يمسّ قسمًا آخر ولا عنصرًا.
-- نفّذه في Supabase ← SQL Editor ← الصق ← Run (مشروع DeshoStore)، وارفع
-- web/data/quran/mushafs.json إلى مستودع التغذية أولًا (node tools/gen-quran-catalog.mjs).

begin;

-- 1) قيد التخطيط: بلا توسيعه ترفض القاعدة حفظ القسم الجديد.
alter table public.sections drop constraint if exists sections_layout_check;
alter table public.sections add constraint sections_layout_check check (
  layout in ('richArticle','list','cards','profiles','offers','ads','rates','directory',
             'apps','channels','prayer','weather','converter','calendar','memorials','trains',
             'results','schedule','campaigns','quran','tasks','matches','hadith')
);

-- 2) القسم: ترتيبه ٩٩ — بعد الحملات (٩٨) وقبل إعلانات القرية (١٠٠)، فخدمةُ تلاوةٍ لا
--    تزاحم أخبارَ القرية على الرئيسية، ولا تُرسَل عنها تنبيهات، ولا يُجاورها إعلانُ شركة.
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, feed_url, sort_order, enabled,
   show_on_home, notify_default, allow_breaking, items_source, note)
values
  ('quran_download', 'تحميل القرآن الكريم',
   'اختر الرواية والقارئ والسورة: تنزيلٌ إلى جهازك ثم استماعٌ بلا اتصال',
   'quran', 'quran', 'json', 'data/quran/mushafs.json', 99,
   true, false, false, false, 'file',
   'محتوى القسم كتالوجٌ مولَّد بأداة المستودع tools/gen-quran-catalog.mjs من الواجهة العامة '
   || 'لموقع mp3quran.net (رواية/قارئ/أسلوب تلاوة/خادم/قائمة السور)، ولا عناصرَ له في اللوحة: '
   || 'لا تضف عنصرًا هنا فلن يُنشر، لأن publish.mjs ينشر عناصر الأقسام التي items_source=admin '
   || 'فقط. لتحديث المصاحف: شغّل المولِّد ثم ارفع web/data/quran/mushafs.json إلى مستودع '
   || 'التغذية؛ ولمعاينة الأسماء: node tools/verify-quran.mjs. أسماءُ السور وعددها في التطبيق '
   || 'لا في القاعدة، لأنّها لا تتغيّر. ولا يُخزَّن صوتٌ على خادم القرية: التحميلُ من موزّع '
   || 'mp3quran مباشرةً عند طلب المستخدم، والروايةُ المختارة تُحفظ في إعدادات جهازه.')
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
  layout_def  text;
  sec         public.sections%rowtype;
  n_items     integer;
  n_quran     integer;
begin
  select pg_get_constraintdef(oid) into layout_def
    from pg_constraint where conname = 'sections_layout_check';
  select * into sec from public.sections where id = 'quran_download';

  select count(*) into n_items from public.items
   where section_id = 'quran_download' and status = 'published';

  if layout_def like '%quran%' then
    raise notice 'NOTICE: القيد قبِل quran، فاللوحة تحفظ القسم بلا رفض.';
  else
    raise warning 'WARNING: لم يُوسَّع قيد التخطيط: %', coalesce(layout_def, 'لا قيد');
  end if;

  if sec.id is null then
    raise warning 'WARNING: لا صفّ quran_download في sections — لن يظهر القسم في التطبيق.';
    return;
  end if;

  raise notice 'NOTICE: قسم التحميل جاهز: layout=%, icon=%, sort=%، على الرئيسية=%، تنبيه=%، مصدر=%، ملف=%',
    sec.layout, sec.icon, sec.sort_order, sec.show_on_home, sec.notify_default,
    sec.items_source, coalesce(sec.feed_url, 'لا شيء');

  if sec.items_source <> 'file' or coalesce(sec.feed_url, '') <> 'data/quran/mushafs.json' then
    raise warning 'WARNING: القسم ليس fileً موصولًا بكتالوجه (items_source=%, feed_url=%) — '
      'سينتظر عناصرَ لوحةٍ لا تأتي، فلن يرى التطبيق مصحفًا واحدًا.',
      sec.items_source, coalesce(sec.feed_url, 'لا شيء');
  end if;

  if sec.show_on_home then
    raise warning 'WARNING: القسم يظهر على الرئيسية؛ قائمةُ تنزيلٍ لا تزاحم أخبار القرية.';
  end if;
  if sec.notify_default or sec.allow_breaking then
    raise warning 'WARNING: تنبيهاتٌ مفعّلة (notify=%, breaking=%)؛ لا «عاجل» في مصحف.',
      sec.notify_default, sec.allow_breaking;
  end if;

  -- عنصرٌ بقي من محاولة يدوية؟ لن يُنشر، فالقسم لم يعد مُدارًا — والازدواج يُربك القارئ.
  if n_items > 0 then
    raise warning 'WARNING: % عنصرًا منشورًا في items للقسم؛ قسم file لا يقرأ إلا كتالوجه. أرشفها.', n_items;
  else
    raise notice 'NOTICE: لا عناصر في items للقسم — المحتوى كله في ملفه المولَّد.';
  end if;

  -- لا شيء «قرآني» مُذرَع في أقسام أخرى: السورُ لا تسكن جدول أخبار القرية.
  select count(*) into n_quran from public.items
   where status = 'published' and title like '%سورة%';
  if n_quran > 0 then
    raise warning 'WARNING: % عنصرًا بعنوانٍ يبدأ فيه «سورة» في أقسام أخرى — راجعها؛ فالتلاوات لها قسمها.', n_quran;
  end if;
end $$;

-- 5) ما سيراه التطبيق (قراءة فقط): صفّ القسم كما يُطبع في index.json.
select s.id, s.title, s.layout, s.icon, s.source_kind, s.feed_url, s.items_source,
       s.sort_order, s.enabled, s.show_on_home, s.notify_default, s.allow_breaking
  from public.sections s
 where s.id = 'quran_download';
