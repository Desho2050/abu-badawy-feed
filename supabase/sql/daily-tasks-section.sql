-- قسم «مهامي اليومية»: صفٌّ في الأقسام بلا تغذيةٍ ولا عناصر — بياناتُ المستخدم على جهازه.
--
-- لماذا صَفٌّ أصلًا؟ لأن التطبيق يقرأ درجَ الأقسام من index.json الذي يطبعه publish.mjs
-- من جدول sections؛ وDEFAULT_SECTIONS في التطبيق شبكةُ أمانٍ لأول تشغيلٍ بلا اتصال فقط
-- (Repository.sections، السطر 82). فبلا هذا الصفّ لا يصل القسم إلى المستخدم الذي يملك
-- اتصالًا — وهو أغلبهم.
--
-- القياس لا الرواية (٢٠٢٦-١٠-٢٠، من هذا المستودع): قيدُ القاعدة
--   sections_items_source_check = check (items_source in ('admin','file'))
-- لا يسمح بقيمة 'local' التي اقترحتها المواصفات أولًا، فلا تُوسَّع قيودُ التغذيةِ لأجل
-- قسمٍ لا يُنشر منه شيء. والبديل المقيس موجودٌ أصلًا: source_kind='inline'، وناشرُ
-- المستودع يكتب عناصرَ الأقسام التي (items_source=admin و kind=json) معًا (publish.mjs،
-- السطران 671 و 802)، فجعلُ النوع inline يُبقي هذا القسم خارج مسار العناصر كلّه بلا
-- قيدٍ جديد. والتطبيقُ من جهته لا يجلب له شيئًا: فرعُ Layout.TASKS في SectionViewModel
-- يراقب TaskStore المحليّ وحده، وContentSource (السطر 70) يعتبر النوع inline بلا شبكة.
--
-- لا مهمةَ تُذرَع هنا اختبارًا: المهامُ ملكُ صاحب الجهاز، ونسخةٌ وهميةٌ منها في تغذية
-- القرية تعني أن مهامَ شخصٍ تُرى لغيره — وهو عكس الوعدِ المكتوبِ على الشاشة نفسها
-- («المهامُ كلّها على جهازك وحدك: لا تُرفع إلى خادمٍ ولا تظهر لأحدٍ غيرك»).
--
-- آمن للتكرار: يزكّي صفَّ القسم وحده، ولا يمسّ قسمًا آخر ولا عنصرًا.
-- نفّذه في Supabase ← SQL Editor ← New query ← الصق ← Run (مشروع DeshoStore).
-- لا يُرفَع شيءٌ إلى Play ولا إلى مستودع التغذية بأمرٍ من هذا الملف: هو قيدُ قسمٍ فقط.

begin;

-- 1) لا تعديلَ لقيدٍ هنا: القيدُ الحيُّ — وقيدُ supabase-setup.sql في مشروعٍ جديد — يقبل
--    كلَّ تخطيطٍ ومصدرٍ تُدرجه هذه البذرة. كان الملفُ يوسّعُ القيدَ بـ drop ثم add، فحُذف
--    لسببين: drop constraint يُفعِّل حرّاسَ اللوحة التدميريةَ فيُبطل التشغيلَ بصمت، والقائمةُ
--    التي يُعيدُها المشغّلُ أقدمُ من 'jobs' و'fixes' فتنقصُهما من السمة. احتاجتِ السمةُ
--    قيدًا جديدًا، فاذكرهُ في ملفٍ مستقلٍّ لا تُشغّلُه اللوحةُ وحده.

-- 2) القسم: ترتيبه ٩ — بعد حالة الطقس (٨) وقبل التعريف بالقرية (١٠)، بين خدماتِ الجهاز
--    التي لا تنتظر اتصالًا. لا ملفَ له (feed_url null) ولا نوعَ تغذيةٍ سوى inline.
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, feed_url, sort_order, enabled,
   show_on_home, notify_default, allow_breaking, items_source, note)
values
  ('daily_tasks', 'مهامي اليومية',
   'قائمةُ مهامٍ لليومِ أو غدًا على جهازك، وتنبيهٌ في وقتها وواحدٌ بعدها إن لم تُنجزها',
   'tasks', 'tasks', 'inline', null, 9,
   true, false, false, false, 'admin',
   'قسمٌ محليٌّ بالكامل: لا عناصرَ له في هذا الجدول ولا ملفَ تغذية، ومصدرُه inline ليظلّ خارج '
   || 'مسار نشر العناصر (publish.mjs يكتب items للأقسام admin+json وحدها). المهامُ في DataStore '
   || 'كلّ جهازٍ باسم tasks.v1، والتذكيرُ منبّهٌ محليٌّ (AlarmManager) لا إشعارَ قريةٍ ولا ملخّص: '
   || 'فلا تُفعّل notify_default ولا show_on_home هنا. لا تضف مهمةً في اللوحة — لن تُنشر، ولا '
   || 'تُختبر واجهةُ القسم هنا لأن لا واجهةَ له؛ أدواتُه tools/verify-tasks.mjs واختباراتُ '
   || 'التطبيق. والمعلنةُ في الشاشة: المنبّهاتُ الدقيقةُ قد تُرفضُ فيؤخّر النظامُ التنبيهَ حتى '
   || 'عشرِ دقائق، وإعادةُ تشغيل الجهاز تمسح الجدولةَ فيعيدها التطبيقُ عند الإقلاع.')
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

-- 3) لا يلتقط PostgREST الجدولَ الجديد حتى تُحمَّل خطته.
select pg_notify('pgrst', 'reload schema');

commit;

-- 4) تدقيق (قراءة فقط): WARNING عند خللٍ يمنع القسم أو يكذب على المستخدم، NOTICE عند السلامة.
do $$
declare
  layout_def text;
  items_def  text;
  sec        public.sections%rowtype;
  n_items    integer;
  n_same     integer;
begin
  select pg_get_constraintdef(oid) into layout_def
    from pg_constraint where conname = 'sections_layout_check';
  select pg_get_constraintdef(oid) into items_def
    from pg_constraint where conname = 'sections_items_source_check';
  select * into sec from public.sections where id = 'daily_tasks';

  if layout_def like '%tasks%' then
    raise notice 'NOTICE: القيد قبِل tasks، فاللوحة تحفظ القسم بلا رفضٍ صامت.';
  else
    raise warning 'WARNING: لم يُوسَّع قيد التخطيط: %', coalesce(layout_def, 'لا قيد');
  end if;

  -- قيدُ مصدرِ العناصر هو سببُ اختيار inline: لو وسّعه أحدٌ بـ'local' فالقرارُ يُراجَع لا يُنفَّذ أعمى.
  if items_def is null then
    raise warning 'WARNING: لا قيدَ sections_items_source_check باسمه — راجع كيف تُمنع عناصرُ هذا القسم.';
  else
    raise notice 'NOTICE: مصدرُ العناصر مقصورٌ على %؛ فلا «local» في القاعدة، وinline هو المقياس.', items_def;
  end if;

  if sec.id is null then
    raise warning 'WARNING: لا صفّ daily_tasks في sections — لن يظهر القسم لمن عنده اتصال.';
    return;
  end if;

  raise notice 'NOTICE: قسم المهام جاهز: layout=%, kind=%, sort=%، رئيسية=%، تنبيه=%، مصدر=%، ملف=%',
    sec.layout, sec.source_kind, sec.sort_order, sec.show_on_home, sec.notify_default,
    sec.items_source, coalesce(sec.feed_url, 'لا شيء');

  -- inline لا json: بهذا وحده لا يكتب الناشرُ ملفَ عناصرٍ للقسم.
  if sec.source_kind <> 'inline' then
    raise warning 'WARNING: مصدر القسم % لا inline — سيُنشر له ملفُ عناصرَ لا يقرؤه التطبيق، '
      'وتُعرض واجهتُه في الدرج على أنها تغذيةُ قرية.', sec.source_kind;
  end if;

  if coalesce(sec.feed_url, '') <> '' then
    raise warning 'WARNING: للقسم رابطُ تغذية (%) ولا ملفَ له — وعدٌ بملفٍ لا يوجد.', sec.feed_url;
  end if;

  if sec.show_on_home then
    raise warning 'WARNING: القسم على الرئيسية؛ مهامُ شخصٍ واحدٍ لا تُعرض بين أخبار القرية.';
  end if;

  if sec.notify_default or sec.allow_breaking then
    raise warning 'WARNING: تنبيهاتُ القرية مفعّلة للقسم (notify=%, breaking=%)؛ تذكيرُ المهمة '
      'يُجدوله صاحبُ الجهاز من تطبيقه، لا ملخّصُ القرية.',
      sec.notify_default, sec.allow_breaking;
  end if;

  select count(*) into n_items from public.items where section_id = 'daily_tasks';
  if n_items > 0 then
    raise warning 'WARNING: % عنصرًا في items للقسم؛ لا واحدٌ منها يُنشر ولا يظهر، وأرشفتُها أصدق.',
      n_items;
  else
    raise notice 'NOTICE: لا عناصرَ في items للقسم — ولا يُذرَع فيها اختبارًا.';
  end if;

  select count(*) into n_same from public.sections
   where sort_order = sec.sort_order and id <> sec.id and enabled;
  if n_same > 0 then
    raise warning 'WARNING: % قسمًا آخر بنفس الترتيب (%) — ترتيبُ الدرجِ بينهما لا يُتحكّم فيه.',
      n_same, sec.sort_order;
  end if;
end $$;

-- 5) ما سيراه التطبيق (قراءة فقط): صفّ القسم كما يُطبع في index.json.
select s.id, s.title, s.layout, s.icon, s.source_kind, s.feed_url, s.items_source,
       s.sort_order, s.enabled, s.show_on_home, s.notify_default, s.allow_breaking
  from public.sections s
 where s.id = 'daily_tasks';
