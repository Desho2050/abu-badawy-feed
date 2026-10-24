-- قسم «قراءةُ القرآن الكريم»: نصٌّ يُقرأُ من ملفٍّ منشور، وتلاوةٌ تُربَطُ عند النقرِ لا تُخزَّن.
--
-- اقرأ هذا أولًا: القيدُ الحيُّ على sections.layout لا يعرف 'quranRead' بعدُ، فأسقطهُ في
-- مشروعك قبلَ هذا الملف — شغّل supabase/sql/widen-layout-quran-read.sql (في SQL Editor
-- مباشرةً، لا من اللوحة: drop constraint يُفعِّل حرّاسَها التدميريةَ فيُبطل التشغيلَ بصمت).
-- بغيرِ التوسيعِ يرفضُ القيدُ الإدراجَ كلَّهُ، ورسالتُه تسمّي sections_layout_check.
--
-- لماذا ملفٌ مولَّد لا عناصر لوحة؟ لأنَّ المحتوى ليس أخبارًا: ١١٤ سورةً بآياتِها كلها
-- (٦٢٣٦ آيةٍ بالرسم المدني) مع مواضعِ النزولِ وبداياتِ الأجزاءِ وأرقامِ الصفحاتِ —
-- ١٫٤ م.ب. من الحروفِ لا تُحقنُ سطرًا سطرًا في جدول items: تفقدُ البنيةَ التي يحتاجها
-- التطبيقُ (أيُّ آيةٍ في أيِّ صفحةٍ وجزء، وكم آيةَ سورةٍ، وأين تبدأُ كلُّ جزء) وتملأُ
-- اللوحةَ بصفوفَ لا يُحرَّر منها شيء. فالقاعدةُ التي جعلت مصحفَ التنزيلِ قسمَ file
-- (quran-download-section.sql) هي نفسها هنا، مع مِشْبَكِ هذا التخطيط: publish.mjs لا
-- ينشر عناصرَ الأقسامِ التي items_source=admin (وحارسُ CATALOG_LAYOUTS يرفضُ حتى أن
-- يكتبَ items فارغةً فوقَ ملفٍّ مولَّد)، فجعلُ القسمِ fileً وربطُهُ بملفِّه يكفي.
--
-- لا نصَّ قرآنٍ على خادم القرية ولا صوتَ: الملفُ يُرفعُ إلى مستودعِ التغذية (GitHub
-- Pages) كما يُرفعُ mushafs.json، والجهازُ ينزّلُهُ مرةً واحدةً إلى مجلده ويقرأُهُ من
-- القرصِ بعدَ ذلك بلا شبكة. والنصُّ كلُّهُ من مشروع تنزيل (Tanzil) بشرطِهِ: ذكرُ المصدرِ
-- على الشاشةِ من حقل attribution في الملفِ لا من كودِ التطبيقِ، ولا يُبدَّلُ حرفٌ ولا
-- تُزادُ علامةُ وقفٍ (§٣-١١). والتلاوةُ تدفُّقٌ من موزّع mp3quran عندَ نقرِ المستخدم،
-- لا ملفٌّ يُنسخُ إلى هنا — فلا قائمةَ سورٍ ولا اسمَ قارئٍ ولا رابطَ صوتٍ في هذا الصف.
--
-- الترتيبُ ٩٩ مثلَ صفِّ التنزيلِ عمدًا: الفرزُ المنشورُ يفصلُ بالتساوي بالمعرِّف
-- (publish.mjs: (a.sort_order - b.sort_order) || id.localeCompare)، فـ quran_download
-- تسبقُ quran_reader ولا يحتاجُ أيٌّ من الصفَّينِ إعادةَ ترقيمٍ، ولا يُزاحمُ إعلانُ
-- القريةِ (١٠٠) مصحفًا. وعلى الرئيسيةِ لا يظهرُ، وعنهُ لا تنبيهَ: خدمةُ قراءةٍ لا
-- تزاحمُ أخبارَ القرية، و«عاجل» لا يكونُ في مصحف.
--
-- آمنٌ للتكرار: يزكّي صفَّ القسمِ وحده، ولا يمسُّ قسمًا آخرَ ولا عنصرًا.
-- نفّذه في Supabase ← SQL Editor ← الصق ← Run (مشروع DeshoStore) بعدَ توسيعِ القيد،
-- وارفع web/data/quran/text.json إلى مستودعِ التغذية أولًا
-- (node tools/gen-quran-text.mjs ← node tools/verify-quran-text.mjs).

begin;

-- 1) لا تعديلَ للقيدِ هنا: انظر رأسَ الملف.

-- 2) القسمُ: نسخةُ النصِّ في الملفِ، وعقدُ البياناتِ في §٣ من SPEC-QURAN-READER.md.
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, feed_url, sort_order, enabled,
   show_on_home, notify_default, allow_breaking, items_source, note)
values
  ('quran_reader', 'قراءةُ القرآن الكريم',
   'اقرأ السورَ بالرسم المدني وتتبعَ التلاوةَ آيةً آية',
   'quran', 'quranRead', 'json', 'data/quran/text.json', 99,
   true, false, false, false, 'file',
   'محتوى القسم ملفٌّ مولَّد بأداة المستودع tools/gen-quran-text.mjs: نصُّ مصحف المدينة '
   || 'بالرسم العثماني من مشروع تنزيل (Tanzil) مع بياناتِ الصفحاتِ والأجزاءِ ومواضعِ النزول، '
   || 'ولا عناصرَ له في اللوحة: لا تضف سورةً ولا آيةً هنا فلن تُنشر. للتحديث شغّل المولِّد '
   || 'ثم ارفع web/data/quran/text.json إلى مستودع التغذية، وعاينه بـ '
   || 'node tools/verify-quran-text.mjs. ولا يُخزَّن نصٌّ ولا صوتٌ على خادم القرية.')
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

-- 3) لا يلتقط PostgREST الجدولَ حتى تُحمَّل خطتُهُ.
select pg_notify('pgrst', 'reload schema');

commit;

-- 4) تدقيق (قراءةٌ فقط): WARNING عند خللٍ يمنعُ القسم، NOTICE عند السلامة.
do $$
declare
  layout_def  text;
  sec         public.sections%rowtype;
  n_items     integer;
  n_files     integer;
  note_len    integer;
begin
  select pg_get_constraintdef(oid) into layout_def
    from pg_constraint where conname = 'sections_layout_check';
  select * into sec from public.sections where id = 'quran_reader';

  if layout_def like '%quranRead%' then
    raise notice 'NOTICE: القيد قبِل quranRead، فاللوحة تحفظ القسم بلا رفض.';
  else
    raise warning 'WARNING: لم يُوسَّع قيد التخطيط: %', coalesce(layout_def, 'لا قيد');
    raise warning 'WARNING: أوقف توسيعَ widen-layout-quran-read.sql ثم أعد هذا الملف — '
      'فالإدراجُ بـ layout=quranRead سيرفضُهُ القيد.';
  end if;

  if sec.id is null then
    raise warning 'WARNING: لا صفّ quran_reader في sections — لن يظهر القسم في التطبيق.';
    return;
  end if;

  raise notice 'NOTICE: قسم القراءة جاهز: layout=%, icon=%, sort=%، على الرئيسية=%، تنبيه=%، مصدر=%، ملف=%',
    sec.layout, sec.icon, sec.sort_order, sec.show_on_home, sec.notify_default,
    sec.items_source, coalesce(sec.feed_url, 'لا شيء');

  -- التخطيطُ عنوانُ العقدِ بين اللوحةِ والتطبيق: 'quran' يفتحُ شاشةَ التنزيلِ لا القراءة.
  if sec.layout <> 'quranRead' then
    raise warning 'WARNING: layout=% لا quranRead — سيفتحُ التطبيقُ قسمًا بتخطيطٍ آخرَ '
      'وينتظرُ عناصرَ لا تأتي.', sec.layout;
  end if;

  if sec.items_source <> 'file' or coalesce(sec.feed_url, '') <> 'data/quran/text.json' then
    raise warning 'WARNING: القسم ليس fileً موصولًا بملفِّه (items_source=%, feed_url=%) — '
      'سينتظر عناصرَ لوحةٍ لا تأتي، فلن يرى التطبيقُ آيةً واحدة.',
      sec.items_source, coalesce(sec.feed_url, 'لا شيء');
  end if;

  if sec.show_on_home then
    raise warning 'WARNING: القسم يظهر على الرئيسية؛ قائمةُ سورٍ لا تزاحم أخبار القرية.';
  end if;
  if sec.notify_default or sec.allow_breaking then
    raise warning 'WARNING: تنبيهاتٌ مفعّلة (notify=%, breaking=%)؛ لا «عاجل» في مصحف.',
      sec.notify_default, sec.allow_breaking;
  end if;

  -- لا يصحُّ أن يسكنَ نفسَ الملفِ قسمان: التنزيلُ يقرأُ mushafs.json والقراءةُ text.json.
  select count(*) into n_files from public.sections
   where items_source = 'file' and feed_url = 'data/quran/text.json';
  if n_files > 1 then
    raise warning 'WARNING: % قسمًا موصولًا بـ data/quran/text.json — دَع للقراءةِ قسمًا واحدًا.', n_files;
  end if;

  -- عنصرٌ بقي من محاولةٍ يدوية؟ لن يُنشر، فالقسمُ غيرُ مُدار — والازدواجُ يُربك القارئ.
  select count(*) into n_items from public.items
   where section_id = 'quran_reader' and status = 'published';
  if n_items > 0 then
    raise warning 'WARNING: % عنصرًا منشورًا في items للقسم؛ قسم file لا يقرأ إلا ملفَّه. أرشفها.', n_items;
  else
    raise notice 'NOTICE: لا عناصر في items للقسم — النصُّ كلُّه في ملفِّه المولَّد.';
  end if;

  -- اللوحةُ تعدُّ note بأربعمئةِ حرف؛ ما زادَ لا يراه أحدٌ على الشاشةِ ولا في التغذية.
  -- والـ«%» بلا وسيطٍ يُبطلُ التشغيلَ كلَّهُ برسالةِ «too few arguments in RAISE».
  select coalesce(length(sec.note), 0) into note_len;
  if note_len > 400 then
    raise notice 'NOTICE: طولُ الحاشية % حرفًا — تُقطعُ عند النشرِ ولا تُعرضُ في التطبيق.', note_len;
  else
    raise notice 'NOTICE: الحاشية % حرفًا، تحت حدِّ اللوحة.', note_len;
  end if;

end $$;

-- 5) ما سيراه التطبيق (قراءةٌ فقط): صفُّ القسمِ كما يُطبعُ في index.json.
select s.id, s.title, s.layout, s.icon, s.source_kind, s.feed_url, s.items_source,
       s.sort_order, s.enabled, s.show_on_home, s.notify_default, s.allow_breaking
  from public.sections s
 where s.id = 'quran_reader';
