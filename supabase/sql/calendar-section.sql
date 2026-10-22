-- قسم «التقويم الهجري والميلادي»: قسم حيّ رابع — لا عناصر له في القاعدة.
-- التطبيق يبني الشبكة والتحويل بنفسه من api.aladhan.com (method=5، نفس طريقة
-- قسم المواقيت)، ويحفظ نسخة لكل شهر على الجهاز، فيعمل التنقّل بين الأشهر بلا
-- إنترنت بعد أول فتح. المناسبات جدول عربي منتقى داخل التطبيق (ثلاثة عشر سطرًا
-- لعشر مناسبات، منها أيام التشريق)، لا قائمة الواجهة الإنجليزية.
--
-- ما يقدّمه القسم:
--   شبكة شهر ميلادي تبدأ السبت، وفي كل خلية رقم اليوم الهجري وشرطة لو فيه مناسبة
--   قائمة مناسبات الشهر بتأريخه في التقويمين
--   محوّل تاريخين: ميلادي ← هجري وبالعكس، مع اسم اليوم بالعربية
--
-- آمن للتكرار (idempotent): يزكي صفًّا واحدًا.
-- نفّذه في Supabase ← SQL Editor ← New query ← الصق ← Run (مشروع DeshoStore).
-- القيدُ لا يُعدَّل في البذرة: قائمةُ layouts وsource_kind في supabase-setup.sql هي
-- المرجعُ الواحد، فأيُّ ترتيبٍ لتشغيل هذه الملفات آمن.

-- 1) لا تعديلَ لقيدٍ هنا: القيدُ الحيُّ — وقيدُ supabase-setup.sql في مشروعٍ جديد — يقبل
--    كلَّ تخطيطٍ ومصدرٍ تُدرجه هذه البذرة. كان الملفُ يوسّعُ القيدَ بـ drop ثم add، فحُذف
--    لسببين: drop constraint يُفعِّل حرّاسَ اللوحة التدميريةَ فيُبطل التشغيلَ بصمت، والقائمةُ
--    التي يُعيدُها المشغّلُ أقدمُ من 'jobs' و'fixes' فتنقصُهما من السمة. احتاجتِ السمةُ
--    قيدًا جديدًا، فاذكرهُ في ملفٍ مستقلٍّ لا تُشغّلُه اللوحةُ وحده.

-- 2) القسم: بلا feed_url ولا عناصر، والتطبيق يعرف مصدره من kind وحده.
--    ترتيبه 6 فيلي فورًا بعد مواقيت الصلاة، فإن كان قسم المواقيت معطّلًا ظهر
--    وحده في رأس الدرج.
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, sort_order, enabled, show_on_home,
   notify_default, allow_breaking, note)
values
  ('calendar', 'التقويم الهجري', 'شهر ميلادي بهوامش هجرية، ومناسبات، وتحويل بين التقويمين',
   'calendar', 'calendar', 'calendar', 6,
   true, true, false, false,
   'يحسبه التطبيق من api.aladhan.com بنفس إحداثيات موقع القرية (الإعدادات ← موقع القرية).')
on conflict (id) do update
  set title       = excluded.title,
      subtitle    = excluded.subtitle,
      icon        = excluded.icon,
      layout      = excluded.layout,
      source_kind = excluded.source_kind,
      sort_order  = excluded.sort_order,
      note        = excluded.note;

-- 3) تدقيق (قراءة فقط): يرفع NOTICE عند الجاهزية وWARNING عند النقص.
do $$
declare
  cal         public.sections%rowtype;
  layout_def  text;
  kind_def    text;
  has_place   integer;
begin
  select * into cal from public.sections where id = 'calendar';

  select pg_get_constraintdef(oid) into layout_def
    from pg_constraint where conname = 'sections_layout_check';
  select pg_get_constraintdef(oid) into kind_def
    from pg_constraint where conname = 'sections_source_kind_check';

  select count(*) into has_place
    from information_schema.columns
   where table_schema = 'public' and table_name = 'app_settings' and column_name = 'location';

  if cal.id is null then
    raise warning 'WARNING: لا صف calendar في sections — لن يظهر القسم في التطبيق.';
  else
    raise notice 'NOTICE: قسم التقويم جاهز: layout=%, kind=%, sort=%, enabled=%, show_on_home=%',
      cal.layout, cal.source_kind, cal.sort_order, cal.enabled, cal.show_on_home;
  end if;

  if layout_def like '%calendar%' and kind_def like '%calendar%' then
    raise notice 'NOTICE: القيدان قبِلا calendar، فاللوحة تحفظ القسم بلا رفض.';
  else
    raise warning 'WARNING: أحد القيدَين لم يُوسَّع — layout: % | kind: %',
      coalesce(layout_def, 'لا قيد'), coalesce(kind_def, 'لا قيد');
  end if;

  if has_place = 1 then
    raise notice 'NOTICE: عمود location موجود؛ وإن كان فارغًا يستخدم التطبيق مركز بيلا.';
  else
    raise warning 'WARNING: لا عمود location (نفّذ supabase/sql/almanac-sections.sql) — التقويم سيبقى على الموضع الافتراضي.';
  end if;

  if exists (select 1 from public.sections where id = 'calendar' and enabled = false) then
    raise warning 'WARNING: القسم مُعطَّل؛ فعّله من اللوحة ← الأقسام.';
  end if;
end $$;

-- 4) ما سيراه الناشر في index.json بعد جولة التشغيل القادمة (قراءة فقط)
select id, title, layout, source_kind, sort_order, enabled, show_on_home, feed_url
  from public.sections
 order by sort_order;