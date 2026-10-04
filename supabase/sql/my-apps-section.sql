-- قسم «تطبيقاتي»: قائمة تطبيقات مُصمَّمة، لكل تطبيق أيقونة ووصف ومميزات ورابط.
-- العناصر تُدار من اللوحة (العناصر ← جديد ← القسم: تطبيقاتي) كأي قسم محتوى،
-- والتطبيق يرسمها ببطاقة خاصة: أيقونة مربّعة + الوصف + سطور المميزات + زر
-- «افتح التطبيق» الذي يرسل رابط المتجر إلى نظام التشغيل (بلا أذونات جديدة).
--
-- متفق مع اللوحة والتطبيق في ثلاث اصطلاحات داخل العنصر:
--   الصورة        ← أيقونة التطبيق (مربعة، 192×192 فأكثر)
--   رابط خارجي    ← رابط المتجر أو أي صفحة تخص التطبيق
--   حقل «المميزات» ← مميزات مفصولة بفواصل، وتُعرض سطورًا تحت الوصف
--
-- آمن للتكرار (idempotent): يوسّع قيد layout، ويزكي قسمًا وصفًّا واحدًا.
-- نفّذه في Supabase ← SQL Editor ← New query ← الصق ← Run (مشروع DeshoStore).
-- ملاحظة: قائمة قيد التخطيط هنا مطابقة لقوائم almanac-sections وcalendar-section
-- وcode-channels-section، فأي ترتيب يشغّلها.

-- 1) قيد التخطيط: بلا توسيعه ترفض القاعدة حفظ القسم الجديد.
alter table public.sections drop constraint if exists sections_layout_check;
alter table public.sections add constraint sections_layout_check check (
  layout in ('richArticle','list','cards','profiles','offers','ads','rates','directory',
             'apps','channels','prayer','weather','converter','calendar','memorials','trains')
);

-- 2) القسم: مصدره json وعناصره من اللوحة، فلا ملف تحريره يدويًا ولا رابط تغذية.
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, sort_order, enabled, show_on_home,
   notify_default, allow_breaking, items_source, note)
values
  ('my_apps', 'تطبيقاتي', 'تطبيقات من تصميمي: أيقونة ووصف ومميزات ورابط', 'apps', 'apps', 'json', 95,
   true, true, false, false, 'admin',
   'كل تطبيق عنصر هنا: الصورة أيقونته، و«رابط خارجي» متجره، وحقل «المميزات» سطورًا في البطاقة.')
on conflict (id) do update
  set title       = excluded.title,
      subtitle    = excluded.subtitle,
      icon        = excluded.icon,
      layout      = excluded.layout,
      source_kind = excluded.source_kind,
      sort_order  = excluded.sort_order,
      note        = excluded.note;

-- 3) بذرة واحدة: التطبيق الوحيد المنشور علنًا على Google Play الآن.
--    ابقِ الحالة published وإلا لن ينشره الناشر؛ وبعدها تُضيف بقية تطبيقاتك
--    من اللوحة حين تنشر صفحاتها.
insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name,
   fields, status, sort_order, published_at)
select
  'my_apps',
  'ketabu-raby',
  'القران حياتي',
  'القرآن الكريم بأصوات أشهر القراء، مع أوقات الصلاة والأذكار والتفسير واتجاه القبلة',
  '<p>تطبيق «كتاب رابي» رفيق إسلامي متكامل: قراءة القرآن الكريم بخط عثماني واضح مع تفسير '
    || 'مدمج وأصوات متعددة للقراء، وأوقات الصلاة المحسوبة بدقة حسب موقعك مع إشعارات الأذان، '
    || 'والأذكار الصباحية والمسائية والنوم، إلى جانب البحث في القرآن والإشارات المرجعية وسجل '
    || 'القراءة واتجاه القبلة وعداد التسبيح والمتشابهات القرآنية ومواضيع قرآنية مختارة. '
    || 'يتميز بوضع ليلي مريح للعين وخطوط قابلة للتخصيص، ويعمل بدون إنترنت بعد تحميل البيانات.</p>',
  'https://play-lh.googleusercontent.com/KxRd1Ie31XGwkTwn65iyWirvKILatU2KmbEO-LvaPds_QQwPxGLz9uH1OkAkP-SF4g08S1wy19GJLdjDxYSlllM=w192-h192-rw',
  'https://play.google.com/store/apps/details?id=ketabu.raby&hl=ar',
  'Google Play',
  ('{"المميزات": "خط عثماني واضح مع تفسير مدمج، أصوات متعددة للقراء، أوقات الصلاة مع إشعار الأذان، '
    || 'الأذكار الصباحية والمسائية والنوم، اتجاه القبلة وعداد التسبيح، وضع ليلي وخطوط قابلة للتخصيص، '
    || 'يعمل بدون إنترنت بعد تحميل البيانات", '
    || '"المطوّر": "Desho.Co.Ltd", "الحزمة": "ketabu.raby", "آخر تحديث": "2026-09-28"}')::jsonb,
  'published', 10, now()
where not exists (select 1 from public.items where section_id = 'my_apps' and slug = 'ketabu-raby');

-- 4) تحقّق مطبوع: نتائج في اللوح ورسائل في Running
do $$
declare
  sect   record;
  seeded integer;
  layout_def text;
begin
  select layout, source_kind, items_source into sect
    from public.sections where id = 'my_apps';

  if not found then
    raise warning 'WARNING: قسم my_apps غير موجود — لن يظهر في درج التطبيق.';
  else
    raise notice 'NOTICE: قسم تطبيقاتي جاهز (layout=%, kind=%, items=%).',
      sect.layout, sect.source_kind, sect.items_source;
  end if;

  select count(*) into seeded from public.items
   where section_id = 'my_apps' and status = 'published';

  if seeded > 0 then
    raise notice 'NOTICE: عناصر منشورة في القسم: % — أولها القران حياتي.', seeded;
  else
    raise warning 'WARNING: لا عنصر منشور في my_apps — القسم يظهر «لا يوجد محتوى بعد».';
  end if;

  select pg_get_constraintdef(oid) into layout_def
    from pg_constraint where conname = 'sections_layout_check';
  if layout_def like '%apps%' then
    raise notice 'NOTICE: قيد layout قَبِل apps.';
  else
    raise warning 'WARNING: قيد layout لم يُوسَّع: %', layout_def;
  end if;
end $$;

-- ما سينشره الناشر في index.json و data/sections/my_apps.json (قراءة فقط)
select i.slug, i.title, i.link, i.image,
       i.fields ->> 'المميزات' as features,
       i.status
  from public.items i
 where i.section_id = 'my_apps'
 order by i.sort_order desc, i.published_at desc;
