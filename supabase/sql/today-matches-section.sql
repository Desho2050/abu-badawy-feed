-- قسم «مباريات اليوم»: استطلاعٌ حيٌّ من بوابةٍ خارجية وجدولٌ منشورٌ بختمه — لا عناصر قرية.
--
-- لماذا ملفٌ مولّد لا عناصر لوحة؟ لأن المحتوى ليس أخبارًا: ١٣ مسابقةً حيّة تُقرأ من بوابة
-- ESPN العامة لكل يومٍ على حدة، وجدولُ الدوري المصري منقولٌ من ويكيبيديا العربية برخصة
-- CC BY-SA 4.0 بختم تاريخها. حقنُ هذا في items سطرًا سطرًا يفقد البنية التي تحتاجها الشاشة
-- (أيُّ مسابقةٍ حيّة، وأيُّ يومٍ، وما مصدرُ كلِّ صفٍّ)، ويملأ اللوحة بصفوفَ لا يُحرَّر منها شيء.
-- فالفاصلُ هو الفقرةُ نفسها التي جعلت «مواعيد قطارات مصر» و«تحميل القرآن الكريم» قسم file:
-- publish.mjs يطبع source.url من feed_url لأي قسم json (sectionFileOf)، وينشر عناصر
-- items_source=admin فقط، فجعلُ القسم fileً وربطُه بكتالوجه يُبقي جدولةَ النشر بعيدةً عنه.
--
-- القياس لا الرواية (٢٠٢٦-١٠-٢٠، من هذا الجهاز):
--   * ESPN بلا مفتاح: site.api.espn.com/.../soccer/<slug>/scoreboard?dates=YYYYMMDD يردّ 200
--     بحمولة events، وAccess-Control-Allow-Origin: *. الدوري المصري (egy.1) يردّ 400 — فهو
--     خارج البوابة، ولا يُوسَم بالحيّ لأن ذلك كذبٌ على القارئ.
--   * جدول ويكيبيديا (قالب:جدول الدوري المصري الممتاز 2026-27) مختومٌ `update = 10 سبتمبر 2026`
--     بآخر تنقيح 2026-09-24T08:26:21Z — ٢٥ يومًا قبل اليوم. يُعرض ختمُه لا تاريخُ قراءته،
--     فقديمٌ يُقال قديمًا خيرٌ من قديمٍ يُعرَض حيًّا.
--   * لا إذن جديد: الجلبُ من التطبيق إلى ESPN مباشرةً (CORS مفتوحة)، فلا خادمَ وسيطَ ولا
--     خدمةً أمامية: الاستطلاعُ دقيقةٌ بيناستطلاعَين يرتبط بحياة الشاشة ويتوقف عند إغلاقها.
--
-- لا إعلانَ في هذه الشاشة ولا تنبيهات: لافتةُ شركةٍ بين هدفٍ ونتيجة تُربك القارئ، و«عاجل»
-- من نتيجةِ نادٍ ليست خبرَ قرية.
--
-- آمن للتكرار: يزكّي صفَّ القسم وحده، ولا يمسّ قسمًا آخر ولا عنصرًا.
-- نفّذه في Supabase ← SQL Editor ← الصق ← Run (مشروع DeshoStore)، وارفع ملفات
-- web/data/matches/ الثلاثة إلى مستودع التغذية أولًا (node tools/gen-matches-catalog.mjs).

begin;

-- 1) لا تعديلَ لقيدٍ هنا: القيدُ الحيُّ — وقيدُ supabase-setup.sql في مشروعٍ جديد — يقبل
--    كلَّ تخطيطٍ ومصدرٍ تُدرجه هذه البذرة. كان الملفُ يوسّعُ القيدَ بـ drop ثم add، فحُذف
--    لسببين: drop constraint يُفعِّل حرّاسَ اللوحة التدميريةَ فيُبطل التشغيلَ بصمت، والقائمةُ
--    التي يُعيدُها المشغّلُ أقدمُ من 'jobs' و'fixes' فتنقصُهما من السمة. احتاجتِ السمةُ
--    قيدًا جديدًا، فاذكرهُ في ملفٍ مستقلٍّ لا تُشغّلُه اللوحةُ وحده.

-- 2) القسم: ترتيبه ٦٢ — يأتي بعد أخبار الرياضة (٦٠) مباشرةً، فمباراةُ اليوم جارةُ خبرِها
--    الرياضي، وقبل الأسعار لأن صاحبَ الجنيه يفتح سعره لا جدولَ دوري.
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, feed_url, sort_order, enabled,
   show_on_home, notify_default, allow_breaking, items_source, note)
values
  ('today_matches', 'مباريات اليوم',
   'الدوريات الأوروبية والأفريقية حيّةً، والدوري المصري منسوبًا بتاريخه',
   'matches', 'matches', 'json', 'data/matches/catalog.json', 62,
   true, false, false, false, 'file',
   'محتوى القسم كتالوجٌ مولَّد بأداة المستودع tools/gen-matches-catalog.mjs: مساراتُ المسابقات '
   || 'التي قِيست فأرجعت 200 من بوابة ESPN العامة (بلا مفتاح، بلا خادم وسيط)، وجدولُ الدوري '
   || 'المصري منقولٌ من ويكيبيديا العربية برخصة CC BY-SA 4.0 بختم تاريخها، والأسماءُ العربية '
   || 'منقولةٌ عن مقالات ويكيبيديا العربية في data/matches/teams.json. لا عناصرَ له في اللوحة: '
   || 'لا تضف عنصرًا هنا فلن يُنشر، لأن publish.mjs ينشر عناصر الأقسام التي items_source=admin '
   || 'فقط. للتحديث: شغّل المولِّد ثم ارفع web/data/matches/*.json؛ وللمعاينة: '
   || 'node tools/verify-matches.mjs. النتائجُ الحيّة تُستطلَع عند فتح الشاشة كلَّ دقيقة ولا '
   || 'تُخزَّن على خادم القرية، والدوري المصري ليس حيًّا لأنه خارج ESPN (egy.1 يردّ 400).')
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
  select * into sec from public.sections where id = 'today_matches';

  if layout_def like '%matches%' then
    raise notice 'NOTICE: القيد قبِل matches، فاللوحة تحفظ القسم بلا رفض.';
  else
    raise warning 'WARNING: لم يُوسَّع قيد التخطيط: %', coalesce(layout_def, 'لا قيد');
  end if;

  if sec.id is null then
    raise warning 'WARNING: لا صفّ today_matches في sections — لن يظهر القسم في التطبيق.';
    return;
  end if;

  raise notice 'NOTICE: قسم المباريات جاهز: layout=%, icon=%, sort=%، على الرئيسية=%، تنبيه=%، مصدر=%، ملف=%',
    sec.layout, sec.icon, sec.sort_order, sec.show_on_home, sec.notify_default,
    sec.items_source, coalesce(sec.feed_url, 'لا شيء');

  if sec.items_source <> 'file' or coalesce(sec.feed_url, '') <> 'data/matches/catalog.json' then
    raise warning 'WARNING: القسم ليس fileً موصولًا بكتالوجه (items_source=%, feed_url=%) — '
      'سينتظر عناصرَ لوحةٍ لا تأتي، فلن يرى التطبيق مباراةً واحدة.',
      sec.items_source, coalesce(sec.feed_url, 'لا شيء');
  end if;

  -- الحيُّ لا يُعلَّن على الرئيسية ولا يُنْبئ: معاينةٌ تتجمّد وتكذب بعد دقيقة، و«عاجل» هدف.
  if sec.show_on_home then
    raise warning 'WARNING: القسم يظهر على الرئيسية؛ نتيجةٌ حيّةٌ تتقادم في المعاينة.';
  end if;
  if sec.notify_default or sec.allow_breaking then
    raise warning 'WARNING: تنبيهاتٌ مفعّلة (notify=%, breaking=%)؛ لا «عاجل» في مباراة.',
      sec.notify_default, sec.allow_breaking;
  end if;

  select count(*) into n_items from public.items
   where section_id = 'today_matches' and status = 'published';
  if n_items > 0 then
    raise warning 'WARNING: % عنصرًا منشورًا في items للقسم؛ قسم file لا يقرأ إلا كتالوجه. أرشفها.', n_items;
  else
    raise notice 'NOTICE: لا عناصر في items للقسم — المحتوى كله في كتالوجه المولَّد وفي بوابة ESPN.';
  end if;
end $$;

-- 5) ما سيراه التطبيق (قراءة فقط): صفّ القسم كما يُطبع في index.json.
select s.id, s.title, s.layout, s.icon, s.source_kind, s.feed_url, s.items_source,
       s.sort_order, s.enabled, s.show_on_home, s.notify_default, s.allow_breaking
  from public.sections s
 where s.id = 'today_matches';
