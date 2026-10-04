-- قسم «ولد صالح يدعو له»: تذكرة لكل متوفّى من أهل القرية، فيها اسمه وتاريخ وفاته
-- والدعاء له. الفكرة من حديث «إذا مات الإنسان انقطع عنه عمله إلا من ثلاثة: إلا من
-- صدقة جارية، أو علم يُنتفع به، أو ولد صالح يدعو له» — فالقسم دعوة لا خبر: البطاقة
-- تذكّر بالدعاء، ولا تنعي أحدًا ولا تُعلِن عزاءً.
--
-- هنا DDL واحد: توسيع قيد التخطيط sections_layout_check ليقبل 'memorials'. مصدر
-- العناصر json والعناصر من اللوحة، فلا أعمدة جديدة ولا جدولًا جديدًا.
--
-- اصطلاحات البطاقة داخل عناصر القسم (عنصر = متوفّى واحد):
--   العنوان            ← اسم المتوفّى كما يُعرف بين أهل القرية
--   التاريخ كما يظهر   ← تاريخ الوفاة بصيغة 2026-10-04 (أو 2026-10 إن ضاع اليوم)؛
--                         يتولّى التطبيق بقية الحساب: التاريخ الهجري بجدول أم القرى
--                         المضمّن، وما مضى على الوفاة، والذكرى السنوية قبلها بعشرة أيام
--   السطر التعريفي     ← كنية أو بلد أو «أبو فلان»، ويظهر تحت الاسم
--   المتن (body)       ← دعاء مخصص؛ وإن تُرك فارغًا دعا التطبيق بالدعاء المأثور
--                         الافتراضي (صيغة المذكّر)، فيُكتب لغير المذكّر نصٌ في المتن مثل
--                         «اللهم اغفر لها وارحمها…»
--   الصورة             ← اختيارية، تظهر دائرية إلى جوار الاسم
--   الحقول الإضافية    ← ما يحب الناشر توثيقه، على مثال: العمر، مكان الدفن
--
-- الحقوق والخصوصية: لا ملزم قانونًا بنشر اسم متوفّى وتاريخه، والقسم يُكتب بموافقة
-- أهله؛ فلا يُنقل من صفحات النعي في المواقع الإخبارية (نصها مملوك لصحفها)، والمحتوى
-- كله يدخَل من اللوحة. الاسم والتاريخ معلومات عامة عن شخص متوفّى، والدعاء نص مأثور.
--
-- آمن للتكرار (idempotent): يوسّع قيدًا ويزكي صفًّا واحدًا، ولا يمسّ عناصر أحد.
-- نفّذه في Supabase ← SQL Editor ← New query ← الصق ← Run (مشروع DeshoStore).
-- قائمة أسماء القيد هنا نفسها في almanac-sections وcalendar-section وmy-apps-section
-- وcode-channels-section، فترتيب تشغيل هذه الملفات لا يهم.

-- 1) قيد التخطيط: بلا توسيعه ترفض القاعدة حفظ القسم الجديد.
alter table public.sections drop constraint if exists sections_layout_check;
alter table public.sections add constraint sections_layout_check check (
  layout in ('richArticle','list','cards','profiles','offers','ads','rates','directory',
             'apps','channels','prayer','weather','converter','calendar','memorials','trains')
);

-- 2) القسم: ترتيبه 115 يلي «العزاء والوفيات» (110)، فهو ذاكرته لا إعلانه.
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, sort_order, enabled, show_on_home,
   notify_default, allow_breaking, items_source, note)
values
  ('memorials', 'ولد صالح يدعو له',
   'تذكرة لكل من رحلوا من أهل القرية: اسمه وتاريخ وفاته والدعاء له',
   'memorial', 'memorials', 'json', 115,
   true, true, false, false, 'admin',
   'كل متوفّى عنصر: العنوان اسمه، و«التاريخ كما يظهر» تاريخ الوفاة بصيغة 2026-10-04 '
   || 'فيحسب التطبيق هجريَّه وما مضى وذكراه، والمتن دعاء مخصص وإلا جاء الدعاء الافتراضي '
   || 'في التطبيق. لا يُنقل شيء من صفحات النعي في الصحف؛ العناصر يدوية من اللوحة.')
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
  sec         public.sections%rowtype;
  layout_def  text;
  total       integer;
  dated       integer;
  with_duaa   integer;
begin
  select * into sec from public.sections where id = 'memorials';

  select pg_get_constraintdef(oid) into layout_def
    from pg_constraint where conname = 'sections_layout_check';

  select count(*) into total from public.items where section_id = 'memorials';
  select count(*) into dated from public.items
   where section_id = 'memorials'
     and coalesce(event_date, '') ~ '^\s*[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}\s*($|T)';
  select count(*) into with_duaa from public.items
   where section_id = 'memorials' and coalesce(btrim(body), '') <> '';

  if sec.id is null then
    raise warning 'WARNING: لا صف memorials في sections — لن يظهر القسم في التطبيق.';
  else
    raise notice 'NOTICE: قسم التذكار جاهز: layout=%, kind=%, sort=%, enabled=%, show_on_home=%',
      sec.layout, sec.source_kind, sec.sort_order, sec.enabled, sec.show_on_home;
  end if;

  if layout_def like '%memorials%' then
    raise notice 'NOTICE: القيد قبِل memorials، فاللوحة تحفظ القسم بلا رفض.';
  else
    raise warning 'WARNING: لم يُوسَّع قيد التخطيط — لن تحفظ اللوحة layout=memorials: %',
      coalesce(layout_def, 'لا قيد');
  end if;

  if total = 0 then
    raise warning 'WARNING: لا بطاقات بعد — أضِف من اللوحة ← العناصر ← جديد ← قسم «ولد صالح يدعو له»، باسم المتوفّى في العنوان وبصيغة 2026-10-04 في «التاريخ كما يظهر»، بموافقة أهله.';
  else
    raise notice 'NOTICE: فيه % بطاقة؛ منها % بتاريخ كامل (يوم وشهر وسنة) فيحوّلها التطبيق هجريًا ويحسب ما مضى وذكراها.',
      total, dated;
    if dated < total then
      raise warning 'WARNING: % بطاقة تاريخها غير كامل، فتعرض التاريخ كما كُتب بلا هجري ولا حساب (الصيغة 2026-10-04).',
        total - dated;
    end if;
    raise notice 'NOTICE: % بطاقة بدعاء مكتوب، والبقية بالدعاء الافتراضي في التطبيق.', with_duaa;
  end if;

  if exists (select 1 from public.sections where id = 'memorials' and enabled = false) then
    raise warning 'WARNING: القسم مُعطَّل؛ فعّله من اللوحة ← الأقسام.';
  end if;
end $$;

-- 4) ما سيراه الناشر في index.json بعد جولة النشر القادمة (قراءة فقط)
select id, title, icon, layout, source_kind, sort_order, enabled, show_on_home, items_source
  from public.sections
 order by sort_order;
