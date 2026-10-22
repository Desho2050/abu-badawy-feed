-- قسم «أرقام الطوارئ»: دليل أرقام النجدة والإسعاف والمرافق في مصر.
--
-- الأرقام مأخوذة من https://egytric.com/emergency-numbers ومُتحققٌ منها رقمًا رقمًا
-- مقابل مصدرٍ ثانٍ (صفحة أرقام الطوارئ في Orange مصر وبيانات الوزارات والهيئات).
-- صحّحنا عن الصفحة ثلاثة أمور، فلا تُعدّ الأرقام من هذه الصفحة وحدها:
--   • «طوارئ الغاز الطبيعي ١٢٩» ناقصةٌ من الصفحة أصلًا، فأضفناها.
--   • الصفحة تُعطي ١٢١ للخريطة الكهربائية ولـ«الكوارث الطبيعية» معًا؛ الكهربائيون
--     يؤكدون ١٢١ للكهرباء وحدها، ولا خطّ موحّد معروف للكوارث، فلم ندرج الثانية.
--   • «مساعدة السيارات الكهربائية ١٩٩٩٤» لم ينشره مصدرٌ يمكن التحقق منه، فحُذف.
--
-- العناصر تُدار من اللوحة (العناصر ← جديد ← القسم: أرقام الطوارئ) كأي قسم محتوى،
-- والتطبيق يرسمها صفحةَ دليل: اسم الجهة، ووصفُها، والرقم كبيرًا، وزرَّ «اتصل» يفتح
-- هاتف النظام على الرقم (ACTION_DIAL) — بلا إذن اتصال، وبلا اتصالٍ يبدأ وحده.
--
-- اصطلاح الناشر في العنصر (هو وحده ما يقرؤه التطبيق):
--   fields."الرقم"  ← الرقم المتصل به؛ يظهر كبيرًا ويُطلب عند الضغط على «اتصل».
--                       غابَ الحقل ظهر السطر بلا زرٍّ، فيبقى العنصر مفيدًا كتنبيه.
--   العنوان         ← اسم الجهة كما يعرفها أهل القرية.
--   الوصف           ← متى يُلجأ إليها؛ سطرٌ أو سطران يكفيان.
--   fields."الجهة"  ← الجهة المسؤولة، وfields."متاح" ← مواعيد الخدمة.
--
-- الأرقام الهندية تُقبل كما هي: يحوّلها التطبيق إلى لاتينية قبل العرض والطلب.
-- أضف رقمًا جديدًا من اللوحة وحدها، فتنشره جولة الناشر (كل خمس دقائق) دون تعديل
-- التطبيق ودون رفع نسخة APK. لكن لا تُعدّل رقمًا قبل التحقق منه من مصدرين: هذا
-- القسم يُستخدم في لحظةٍ لا احتمالَ فيها لرقمٍ خاطئ.
--
-- آمن للتكرار (idempotent): ينشئ القسم أو يحدّثه مع اثني عشر رقمًا.
-- نفّذه في Supabase ← SQL Editor ← New query ← الصق ← Run (مشروع DeshoStore).

-- 1) لا تعديلَ لقيدٍ هنا: القيدُ الحيُّ — وقيدُ supabase-setup.sql في مشروعٍ جديد — يقبل
--    'directory' و'jobs' و'fixes' منذ أُنشئت أقسامها (تحقّقٌ بـ pg_get_constraintdef لا
--    بالافتراض). كان هنا drop constraint ثم add، فحُذف لسببين: يُفعِّل حرّاسَ اللوحة
--    التدميريةَ فيُبطل التشغيلَ بصمت، والقائمةُ التي أعاد بها المشغّلُ أقدمُ من 'jobs'
--    فتنقصُها — أيُّ تشغيلٍ له بعد بذرة «فرص عمل» يقطعُ القيدَ ويرجعُ صفَّ jobs مرفوضًا.
--    احتاجتِ السمةُ تخطيطًا جديدًا، فاذكر تعديلَ القيد في ملفٍ مستقلٍّ لا تُشغّلُه اللوحةُ.

-- 2) القسم: sort_order = 7 يضعه مع خدمات اليوم (بعد المواقيت والتقويم وقبل الطقس)،
--    لأنه شاشةٌ تُفتح وقت الحاجة لا وقت التصفّح.
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, sort_order, enabled, show_on_home,
   notify_default, allow_breaking, items_source, note)
values
  ('emergency_numbers', 'أرقام الطوارئ',
   'النجدة والإسعاف والمرافق: رقمٌ ظاهرٌ وزرٌّ يفتح الطلب', 'emergency', 'directory', 'json', 7,
   true, true, false, false, 'admin',
   'كل رقمٍ عنصرٌ هنا، وحقل «الرقم» هو ما يُتصل به. لا تُعدّل رقمًا قبل التحقق من مصدرين؛ الخطأ هنا ليس خطأً مطبعيًّا.')
on conflict (id) do update
  set title       = excluded.title,
      subtitle    = excluded.subtitle,
      icon        = excluded.icon,
      layout      = excluded.layout,
      source_kind = excluded.source_kind,
      sort_order  = excluded.sort_order,
      note        = excluded.note;

-- 3) البذور: رقمٌ لكل عنصر. التكرار لا يزدوجه (where not exists بالـ slug)،
--    فاحذف ما لا تريد من اللوحة بدل التعديل هنا.
insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'emergency_numbers', 'najda-122',
  'شرطة النجدة',
  'الجريمة والحوادث والبلاغات العاجلة على الشرطة',
  '<p>الرقم الأول للحادث القائم: سرقة، مشاجرة، اعتداء، أو اشتباه. اذكر الموقع أولًا '
    || 'ثم ما جرى، وأبقِ الخط مفتوحًا حتى يسألك المُقطِّم؛ الردّ يتقارب في المحافظات '
    || 'لكنه يزداد ازدحامًا ليلًا.</p>',
  null, null, 'وزارة الداخلية', 'https://egytric.com/emergency-numbers',
  '["بلاغات عاجلة"]'::jsonb,
  '{"الرقم": "122", "الجهة": "وزارة الداخلية", "متاح": "٢٤ ساعة", "من": "أي محمول أو أرضي"}'::jsonb,
  'published', 120, now()
where not exists (select 1 from public.items where section_id = 'emergency_numbers' and slug = 'najda-122');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'emergency_numbers', 'ambulance-123',
  'الهيئة العامة للإسعاف',
  'طلب إسعاف مُسيَّر لحالةٍ تُهدّد الحياة',
  '<p>حالةٌ لا تحتمل نقلًا خاصًا: إغماء، نزيف، ألم صدر، حادث طريق، أو صعوبة تنفّس. قل '
    || 'العنوان بالتفصيل ومعالمه، ولا تُغلق الخط قبل أن يكرّر المُسجِّل العنوان. على '
    || 'الطرق السريعة استخدم رقم نجدة الطرق السريعة أدناه أيضًا، فتمركز الدوريات هناك '
    || 'أدنى زمنًا.</p>',
  null, null, 'الهيئة العامة للإسعاف المصرية', 'https://egytric.com/emergency-numbers',
  '["حالات حرجة"]'::jsonb,
  '{"الرقم": "123", "الجهة": "الإسعاف المصري", "متاح": "٢٤ ساعة", "من": "أي محمول أو أرضي"}'::jsonb,
  'published', 115, now()
where not exists (select 1 from public.items where section_id = 'emergency_numbers' and slug = 'ambulance-123');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'emergency_numbers', 'fire-180',
  'الحماية المدنية (المطافئ)',
  'حريق في منزل أو مزرعة أو متجر، أو حصارٌ داخل مبنى',
  '<p>اتصل قبل أن تحاول بمفردك إن كان الدخان يملأ المكان. حدّد المدخل الأقرب وهل في '
    || 'المبنى أحدٌ محاصر — هذا ما يغيّر عربة الإطفاء التي تُرسل. في المزارع والمخازن '
    || 'اذكر نوع المحصول أو المادة المشتعلة، فقد تكون مبيدًا أو وقودًا.</p>',
  null, null, 'وزارة الداخلية — الحماية المدنية', 'https://egytric.com/emergency-numbers',
  '["حرائق"]'::jsonb,
  '{"الرقم": "180", "الجهة": "الحماية المدنية", "متاح": "٢٤ ساعة", "من": "أي محمول أو أرضي"}'::jsonb,
  'published', 110, now()
where not exists (select 1 from public.items where section_id = 'emergency_numbers' and slug = 'fire-180');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'emergency_numbers', 'electricity-121',
  'طوارئ الكهرباء',
  'عمودٌ مكشوف، أو سلكٌ متدلٍّ، أو انقطاعٌ كلّي في الشارع',
  '<p>هذا الخط يُغلقه فنيّ الشركة لا مكتب الاشتراكات. الأخطر ما كان في الماء أو سلكًا '
    || 'يلامس سطحًا معدنيًا: لا تقترب ولا تُدني أحدًا، وانتظر تأكيد الفصل. لأعطال '
    || 'العدّاد والفاتورة رقمٌ آخر عند شركة التوزيع، وهذا الخط للحوادث.</p>',
  null, null, 'الشركة القابضة لكهرباء مصر', 'https://egytric.com/emergency-numbers',
  '["أعطال الشبكة"]'::jsonb,
  '{"الرقم": "121", "الجهة": "طوارئ الكهرباء", "متاح": "٢٤ ساعة", "من": "أي محمول أو أرضي"}'::jsonb,
  'published', 105, now()
where not exists (select 1 from public.items where section_id = 'emergency_numbers' and slug = 'electricity-121');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'emergency_numbers', 'gas-129',
  'طوارئ الغاز الطبيعي',
  'رائحة غاز، أو تسريبٌ بعد عطل، أو خزانٌ تالف',
  '<p>هذا الرقم ناقصٌ في الصفحة الأصلية، أضفناه بعد التحقق. عند الشمِّ: لا تُشعل عود '
    || 'ثقاب ولا تلمس مفتاحًا كهربائيًا — الشرارة الصغيرة هي ما يُشعل الحيز المغلق. '
    || 'افتح النوافذ، وأغلق المفتاح العام للمواسير، ثم اتصل واخرج. إن كان التسريب في '
    || 'شارعٍ لا في بيتك فابقُ بعيدًا عن فتحات التفتيش.</p>',
  null, null, 'شركة تاون جاس / الغاز الطبيعي', 'https://egytric.com/emergency-numbers',
  '["تسريب غاز"]'::jsonb,
  '{"الرقم": "129", "الجهة": "طوارئ الغاز", "متاح": "٢٤ ساعة", "من": "أي محمول أو أرضي"}'::jsonb,
  'published', 100, now()
where not exists (select 1 from public.items where section_id = 'emergency_numbers' and slug = 'gas-129');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'emergency_numbers', 'water-125',
  'طوارئ المياه والصرف',
  'كسرٌ في مواسير الشرب، أو غرق شوارع، أو انسداد صرفٍ يهدّد المنازل',
  '<p>اتصل بالشركة لا بالحى حين يكون العطل في الشبكة: كسر ماسورة رئيسية يهدر يومًا من '
    || 'مخزون القرية ويغرق الطريق. حدّد أقرب معلمٍ للموقع، فأرقام المنازل هنا أقل فائدة '
    || 'من الوصف.</p>',
  null, null, 'شركة مياه الشرب والصرف الصحي', 'https://egytric.com/emergency-numbers',
  '["كسر ماسورة"]'::jsonb,
  '{"الرقم": "125", "الجهة": "مياه الشرب والصرف", "متاح": "٢٤ ساعة", "من": "أي محمول أو أرضي"}'::jsonb,
  'published', 95, now()
where not exists (select 1 from public.items where section_id = 'emergency_numbers' and slug = 'water-125');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'emergency_numbers', 'traffic-128',
  'نجدة المرور',
  'حادث طريق، أو إعاقةٌ كاملة للحركة، أو تجمهرٌ عند معبر',
  '<p>اتصل فورًا إن كان الحادث يسدّ شارعًا أو يعزل قرية عن طريقها، فإزالة السيارات تحتاج '
    || 'محضرًا وحضورًا. وإن كان في الحادث مصاب فأنت تحتاج ١٢٣ أيضًا، فلا تكتفِ برقمٍ واحد. '
    || 'على الطريق الدولي استخدم رقم الطرق السريعة أدناه.</p>',
  null, null, 'الإدارة العامة للمرور', 'https://egytric.com/emergency-numbers',
  '["حوادث الطرق"]'::jsonb,
  '{"الرقم": "128", "الجهة": "المرور", "متاح": "٢٤ ساعة", "من": "أي محمول أو أرضي"}'::jsonb,
  'published', 90, now()
where not exists (select 1 from public.items where section_id = 'emergency_numbers' and slug = 'traffic-128');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'emergency_numbers', 'highway-01221110000',
  'نجدة الطرق السريعة',
  'بلاغات الطريق الدولي والدائري والصحراوي',
  '<p>يبدو رقمَ محمول وليس خطأً مطبعيًا: هو خط نجدة الطرق السريعة كما نشرته الصفحة '
    || 'الأصلية وأكّده مصدرٌ ثانٍ. السبب أن دوريات الطرق السريعة كيانٌ منفصل عن مرور '
    || 'المدن، فاستجابة أقرب دورية على طريق بيلا–المحلة أو القاهرة–الإسكندرية أسرع من '
    || 'تحويلة النجدة العامة.</p>',
  null, null, 'الإدارة العامة للمرور — الطرق السريعة', 'https://egytric.com/emergency-numbers',
  '["طرق سريعة"]'::jsonb,
  '{"الرقم": "01221110000", "الجهة": "نجدة الطرق السريعة", "متاح": "٢٤ ساعة", "من": "محمول أفضل"}'::jsonb,
  'published', 85, now()
where not exists (select 1 from public.items where section_id = 'emergency_numbers' and slug = 'highway-01221110000');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'emergency_numbers', 'tourism-126',
  'شرطة السياحة والآثار',
  'سرقةٌ في سوقٍ أو موقعٍ أثرى، أو ابتزازٌ من مرشد',
  '<p>أقرب فائدةٍ لأهل القرية عند مصيف بلطيم: ما يقع على الشاطئ أو في الأسواق من سرقةٍ '
    || 'أو ابتزازٍ يُبلَّغ هنا، فيأتيك ضابطٌ يفهم الحالة قبل أن تضيّع ساعةً في قسمٍ لا '
    || 'يُخصَّص لها. وإن كان في الحادثة إصابة فابدأ بالإسعاف ثم هذا الخط.</p>',
  null, null, 'وزارة الداخلية — شرطة السياحة', 'https://egytric.com/emergency-numbers',
  '["مصيف بلطيم"]'::jsonb,
  '{"الرقم": "126", "الجهة": "شرطة السياحة والآثار", "متاح": "٢٤ ساعة", "من": "أي محمول أو أرضي"}'::jsonb,
  'published', 80, now()
where not exists (select 1 from public.items where section_id = 'emergency_numbers' and slug = 'tourism-126');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'emergency_numbers', 'health-137',
  'الطوارئ والرعاية العاجلة — وزارة الصحة',
  'أي مستشفى يستقبل الآن، ونصائح التسمّم واللدغات',
  '<p>خطٌّ لوزارة الصحة للمعلومات الطبية العاجلة: أي مستشفى يستقبل حالةً الآن، وكيف '
    || 'تتصرّف عند تسمّمٍ غذائي أو لدغة عقرب قبل الوصول. هو في الغالب لا يرسل إسعافًا، '
    || 'فاطلب ١٢٣ للنقل و١٣٧ للسؤال.</p>',
  null, null, 'وزارة الصحة والسكان', 'https://egytric.com/emergency-numbers',
  '["استفسار طبي"]'::jsonb,
  '{"الرقم": "137", "الجهة": "وزارة الصحة", "متاح": "٢٤ ساعة", "من": "أي محمول أو أرضي"}'::jsonb,
  'published', 75, now()
where not exists (select 1 from public.items where section_id = 'emergency_numbers' and slug = 'health-137');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'emergency_numbers', 'child-16000',
  'الخط الساخن لنجدة الطفل',
  'تعدٍّ على طفل، أو عملٌ في غير سنّه، أو طفلٌ بلا معيل',
  '<p>يستقبل البلاغ المجلس القومي للطفولة والأمومة ويُحيله إلى جهة الحماية. يُقبل '
    || 'التبليغ المجهول، فيستطيع جارٌ أو معلّمٌ أن يُبلّغ عن حالةٍ في القرية دون أن يُعرَف '
    || 'اسمه. تسأل الأخصائية عن العمر والموقع وما جرى، فالأمر أطول من مكالمةٍ قصيرة: '
    || 'اتصل حين يكون الطفل في خطرٍ لا حين تريد شكوى.</p>',
  null, null, 'المجلس القومي للطفولة والأمومة', 'https://egytric.com/emergency-numbers',
  '["حماية الأطفال"]'::jsonb,
  '{"الرقم": "16000", "الجهة": "المجلس القومي للطفولة", "متاح": "٢٤ ساعة", "التبليغ": "مجهولٌ مقبول"}'::jsonb,
  'published', 70, now()
where not exists (select 1 from public.items where section_id = 'emergency_numbers' and slug = 'child-16000');

insert into public.items
  (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
   tags, fields, status, sort_order, published_at)
select
  'emergency_numbers', 'women-15115',
  'خط نجدة المرأة',
  'عنفٌ أسري، أو تهديد، أو بلاغٌ عن امرأةٍ في خطر',
  '<p>يُديره المجلس القومي للمرأة، ويوصل المتصلة بالمساعدة القانونية وبجهة الحماية في '
    || 'وزارة التضامن. إن كان الخطر الجسدي قائمًا الآن فابدأ بـ١٢٢ ثم اتصل هنا ليُفتح '
    || 'ملف متابعة. لا يُسلَّم اسم المتصلة إلى الأهل، لكن إن أمِنَت الطريقة فاحفظ ما '
    || 'يُثبت أنك اتصلت.</p>',
  null, null, 'المجلس القومي للمرأة', 'https://egytric.com/emergency-numbers',
  '["حماية الأسرة"]'::jsonb,
  '{"الرقم": "15115", "الجهة": "المجلس القومي للمرأة", "متاح": "٢٤ ساعة"}'::jsonb,
  'published', 65, now()
where not exists (select 1 from public.items where section_id = 'emergency_numbers' and slug = 'women-15115');

-- 4) تحقّقٍ مطبوع: نتائج في اللوح ورسائل في Running.
do $$
declare
  sect   record;
  seeded integer;
  no_num integer;
  dirty  integer;
begin
  select layout, source_kind, items_source into sect
    from public.sections where id = 'emergency_numbers';

  if not found then
    raise warning 'WARNING: قسم emergency_numbers غير موجود — لن يظهر في درج التطبيق.';
  else
    raise notice 'NOTICE: قسم أرقام الطوارئ جاهز (layout=%, kind=%, items=%).',
      sect.layout, sect.source_kind, sect.items_source;
  end if;

  select count(*) into seeded from public.items
   where section_id = 'emergency_numbers' and status = 'published';

  if seeded >= 12 then
    raise notice 'NOTICE: % رقمًا منشورًا، والناشر يكتبها في data/sections/emergency_numbers.json.', seeded;
  else
    raise warning 'WARNING: العناصر المنشورة % فقط (المتوقع ١٢) — أعد تشغيل الملف أو أضف الناقص من اللوحة.', seeded;
  end if;

  -- أي عنصرٍ بلا حقل «الرقم» يظهر بلا زرّ اتصال: مقصودٌ أحيانًا، وغالبًا خطأ.
  select count(*) into no_num from public.items
   where section_id = 'emergency_numbers' and status = 'published'
     and coalesce(fields ->> 'الرقم', '') = '';

  if no_num > 0 then
    raise warning 'WARNING: % عنصرًا بلا حقل «الرقم» — سيظهر بلا زرّ اتصال. أضف الرقم أو احذف العنصر.', no_num;
  else
    raise notice 'NOTICE: كل عنصرٍ فيه حقل «الرقم»، فأزرار الطلب كلها تعمل.';
  end if;

  -- حروفٌ أو شرطاتٌ في الرقم تُطلب خطأً على الهاتف، فتنكشف في اللحظة الأسوأ.
  select count(*) into dirty from public.items
   where section_id = 'emergency_numbers' and status = 'published'
     and fields ->> 'الرقم' ~ '[^0-9+]';

  if dirty > 0 then
    raise warning 'WARNING: % رقمًا فيه حروفًا أو رموزًا غير الأرقام وعلامة + — نظّفه قبل النشر.', dirty;
  else
    raise notice 'NOTICE: صيغة الأرقام نظيفة (أرقامٌ و + فقط، بلا مسافاتٍ ولا شرطات).';
  end if;
end $$;

-- ما سينشره الناشر في index.json و data/sections/emergency_numbers.json (قراءة فقط)
select i.slug, i.title, i.fields ->> 'الرقم' as number,
       i.fields ->> 'الجهة' as agency, i.status
  from public.items i
 where i.section_id = 'emergency_numbers'
 order by i.sort_order desc;
