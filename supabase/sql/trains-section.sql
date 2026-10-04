-- قسم «مواعيد قطارات مصر»: جدول الرحلات الداخلية يبحث فيه القارئ برقم القطار أو باسم
-- المحطة، ويرى بقيّة التفاصيل (النوع والقيام والوصول والمدة والوقفات والأسعار والأيام).
--
-- لماذا تُدخل المواعيد يدويًا ولا يجلبها التطبيق؟ لأن مصدرها الرسمي لا يسمح آليًا:
--   enr.gov.eg يُرجع كل مساراته — ومنها robots.txt وصفحة الجداول — 302 إلى /login.html
--   (تطبيق Vaadin خلف بوابة دخول)، وwww.enr.gov.eg لا يستجيب للاتصال، ولا توجد مجموعة
--   بيانات مفتوحة عن مواعيد السكك الحديدية، ومرايا المواعيد التجارية نسخٌ منسّقة من
--   إعلان الهيئة يملك تنسيقه أصحابه. فالممنوع هو الجلب من الموقع لا استعمال البيانات نفسها:
--   ينسخ الناشر المواعيد من الإعلان الرسمي أو من لوحة المحطة، ويُنشر الجدول كملف قسم.
-- لهذا يرفض التطبيق أن يدّعي أنه مصدر الوقت: يعرض تاريخ سريان الجدول، وينبّه بعد
-- ثلاثين يومًا، ويفتح «المواعيد الرسمية» من رابط العنصر.
--
-- هنا DDL واحد: توسيع قيد التخطيط sections_layout_check ليقبل 'trains'. مصدر العناصر
-- json وهي من اللوحة، فلا أعمدة جديدة ولا جدولًا جديدًا.
--
-- اصطلاحات الرحلة داخل عناصر القسم (عنصر = رحلة واحدة أو رقمًا واحدًا):
--   العنوان            ← «906 — القاهرة ← الإسكندرية» (الرقم ثم الخط؛ يقرأه التطبيق
--                         ويجمّع الرحلات بخطّها ويرتّبها بأول القيام)
--   التاريخ كما يظهر   ← تاريخ سريان الجدول بصيغة 2026-10-04 (لا تاريخ الموعد اليومي)
--   السطر التعريفي     ← ملاحظة قصيرة مثل «تذاكر تُحجز مسبقًا» أو «عربات مخصوصة»
--   الحقول الإضافية    ← بعشرة أسطر بأسماء ثابتة قدر الإمكان: رقم، النوع، من، إلى،
--                         قيام، وصول، المدة، الوقفات، الأسعار، الأيام؛ يقرأها التطبيق
--                         منها، والباقي يظهر في نهاية البطاقة كما هو؛ ويقتطع publish.mjs
--                         النص عند عشرة أسطر، لكل سطر منها أربعمئة حرف.
--   رابط خارجي         ← صفحة المواعيد الرسمية، ويظهر كزر «افتح المواعيد الرسمية»
--   المتن (body)       ← ملاحظات أطول: أرقام الحجز، شروط الخصم، مواعيد عمل الشباك
--
-- لا يُذرَع شيء هنا: المواعيد حقائق تتغيّر كل بضعة أشهر ولا يمكن التحقق منها من هذا
-- المشروع، فبطاقة بموعد قديم تُضلّل مسافرًا. القسم يبدأ فارغًا حتى يدخَل من اللوحة.
--
-- آمن للتكرار (idempotent): يوسّع قيدًا ويزكي صفًّا واحدًا، ولا يمسّ عناصر أحد.
-- نفّذه في Supabase ← SQL Editor ← New query ← الصق ← Run (مشروع DeshoStore).
-- قائمة أسماء القيد هنا نفسها في almanac-sections وcalendar-section وmy-apps-section
-- وcode-channels-section وmemorials-section، فترتيب تشغيل هذه الملفات لا يهم.

-- 1) قيد التخطيط: بلا توسيعه ترفض القاعدة حفظ القسم الجديد.
alter table public.sections drop constraint if exists sections_layout_check;
alter table public.sections add constraint sections_layout_check check (
  layout in ('richArticle','list','cards','profiles','offers','ads','rates','directory',
             'apps','channels','prayer','weather','converter','calendar','memorials','trains')
);

-- 2) القسم: ترتيبه 85 يلي أسعار الذهب (80) ويُسبق العروض (90)، فهو خدمة يومية.
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, sort_order, enabled, show_on_home,
   notify_default, allow_breaking, items_source, note)
values
  ('trains', 'مواعيد قطارات مصر',
   'جدول الرحلات الداخلية: ابحث برقم القطار أو باسم المحطة',
   'train', 'trains', 'json', 85,
   true, true, false, false, 'admin',
   'كل رحلة عنصر: العنوان رقمها وخطها، وفي الحقول أسطر: رقم، النوع، من، إلى، قيام، وصول، '
   || 'المدة، الوقفات، الأسعار، الأيام، و«التاريخ كما يظهر» تاريخ سريان الجدول. المواعيد '
   || 'تُدخل من الإعلان الرسمي لهيئة السكك الحديدية؛ فالموقع يرفض الجلب الآلي (كل مساراته '
   || 'تحويلة 302 إلى بوابة دخول) ولا مجموعة بيانات مفتوحة، والتطبيق لا يدّعي أنه مصدر الوقت.')
on conflict (id) do update
  set title          = excluded.title,
      subtitle       = excluded.subtitle,
      icon           = excluded.icon,
      layout         = excluded.layout,
      source_kind    = excluded.source_kind,
      sort_order     = excluded.sort_order,
      enabled        = excluded.enabled,
      show_on_home   = excluded.show_on_home,
      items_source   = excluded.items_source,
      note           = excluded.note;

-- 3) تدقيق (قراءة فقط): يرفع NOTICE عند الجاهزية وWARNING عند النقص.
do $$
declare
  sec          public.sections%rowtype;
  layout_def   text;
  total        integer;
  live         integer;
  dated        integer;
  lined        integer;
  linked       integer;
  old_days     integer;
begin
  select * into sec from public.sections where id = 'trains';

  select pg_get_constraintdef(oid) into layout_def
    from pg_constraint where conname = 'sections_layout_check';

  select count(*) into total from public.items where section_id = 'trains';
  select count(*) into live from public.items
   where section_id = 'trains' and status = 'published';
  select count(*) into dated from public.items
   where section_id = 'trains'
     and coalesce(event_date, '') ~ '^\s*[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}\s*($|T)';
  -- أسماء الحقول تُقرأ مطويّة كما يطويها التطبيق، فلا تفرق الهمزة والتاء المربوطة.
  select count(*) into lined from public.items
   where section_id = 'trains'
     and translate(coalesce(fields::text, ''), 'أإآىة', 'ااييه') ~ '"(من|بدايه|انطلاق|المبدا)":'
     and translate(coalesce(fields::text, ''), 'أإآىة', 'ااييه') ~ '"(الي|الوجهه|نهايه)":';
  select count(*) into linked from public.items
   where section_id = 'trains' and coalesce(btrim(link), '') <> '';
  select count(*) into old_days from public.items
   where section_id = 'trains'
     and coalesce(event_date, '') ~ '^\s*[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}'
     and current_date - (to_date(btrim(substring(event_date from '^\s*([0-9]{4}-[0-9]{1,2}-[0-9]{1,2})')),
                                 'YYYY-MM-DD')::date) > 30;

  if sec.id is null then
    raise warning 'WARNING: لا صف trains في sections — لن يظهر القسم في التطبيق.';
  else
    raise notice 'NOTICE: قسم القطارات جاهز: layout=%, kind=%, sort=%, enabled=%, show_on_home=%',
      sec.layout, sec.source_kind, sec.sort_order, sec.enabled, sec.show_on_home;
  end if;

  if layout_def like '%trains%' then
    raise notice 'NOTICE: القيد قبِل trains، فاللوحة تحفظ القسم بلا رفض.';
  else
    raise warning 'WARNING: لم يُوسَّع قيد التخطيط — لن تحفظ اللوحة layout=trains: %',
      coalesce(layout_def, 'لا قيد');
  end if;

  if total = 0 then
    raise warning 'WARNING: لا رحلات بعد — أضِفها من اللوحة ← العناصر ← جديد ← قسم «مواعيد قطارات مصر» منسوخة من إعلان الهيئة؛ فلا يذرَع الجدول آليًا ولا يُلقى من موقعها.';
  else
    raise notice 'NOTICE: فيه % عنصرًا؛ % منشورًا فيملأ ملف القسم، والباقي مسوّدة أو مجدولة فلا تُنشر.',
      total, live;
    if live = 0 then
      raise warning 'WARNING: لا عنصر منشور بعد؛ يترك الناشر ملف القسم كما هو بدل أن يمسحه.';
    end if;
    raise notice 'NOTICE: % بعنصر بتاريخ سريان كامل بصيغة 2026-10-04، فيعرف القارئ قِدَم المواعيد.',
      dated;
    if dated < total then
      raise warning 'WARNING: % عنصر بلا تاريخ سريان كامل، فتظهر بطاقته بلا تنبيه القِدَم.',
        total - dated;
    end if;
    if old_days > 0 then
      raise warning 'WARNING: % عنصر مضى على جدول أكثر من ثلاثين يومًا؛ حدِّث المواعيد أو أعد تاريخ السريان.',
        old_days;
    end if;
    raise notice 'NOTICE: % عنصر بحقلي «من» و«إلى»، فيجمّعها التطبيق بخطّ رحلتها ويرتّبها بأول القيام.',
      lined;
    if lined < total then
      raise warning 'WARNING: % عنصر بلا حقلَي من/إلى، فتُعرض تحت عنوان واحد بلا تجميع؛ والأسماء تُقرأ مطويّة (الهمزة والتاء المربوطة سواء) فلا تُشترط كتابة واحدة.', total - lined;
    end if;
    if linked = 0 then
      raise warning 'WARNING: لا رابط رسمي في أي عنصر؛ «افتح المواعيد الرسمية» لن يظهر — ضع في كل قسم رابطًا إلى صفحة جداول الهيئة أو إلى أرقام الحجز.';
    else
      raise notice 'NOTICE: % عنصر برابط رسمي يظهر كزر في البطاقة.', linked;
    end if;
  end if;

  if exists (select 1 from public.sections where id = 'trains' and enabled = false) then
    raise warning 'WARNING: القسم مُعطَّل؛ فعّله من اللوحة ← الأقسام.';
  end if;
end $$;

-- 4) ما سيراه الناشر في index.json بعد جولة النشر القادمة (قراءة فقط)
select id, title, icon, layout, source_kind, sort_order, enabled, show_on_home, items_source
  from public.sections
 order by sort_order;
