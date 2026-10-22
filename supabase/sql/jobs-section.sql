-- قسم «فرص عمل»: لوحةُ إعلانات توظيفٍ ينشرها أصحابُها من اللوحة.
--
-- لا بذرةَ هنا ولا فرصةً واحدة. السبب ليس كسَلًا: الفرصةُ المختلَقة يدفع إليها
-- أهلُ القرية طلباتٍ وأوقاتًا، فقد يمشي خلف إعلان «مطلوب مهندس في مصنع» إنسانٌ
-- حقيقي. الفراغُ إذن أصدقُ حالات البداية، وشاشةُ التطبيق تقول «لا فرصة منشورة
-- بعد» بدل أن تعرض وظيفةً لا صاحبَ لها.
--
-- العنصرُ يُدار من اللوحة (العناصر ← جديد ← القسم: فرص عمل) كما تُدير «أخبار
-- القرية»، والناشرُ ينشره في جولته كلَّ خمس دقائق. إضافةُ فرصةٍ جديدة — أو تغييرُ
-- موعدٍ، أو أرشفةُ فرصةٍ انقضت — لا تحتاج تعديل التطبيق ولا رفع نسخة APK.
--
-- اصطلاح الناشر في العنصر (وهو ما يقرؤه التطبيق حرفيًّا، بلا جهةٍ تُختلق ولا
-- راتبٍ يُقدَّر):
--   العنوان          ← المسمّى كما نشره المعلن («مطلوب محاسب»).
--   fields."الجهة"    ← صاحب العمل؛ يقبل أيضًا «الشركة» و«صاحب العمل». غابَ بقي
--                        المعلن مجهولًا كما نُشر.
--   fields."المجال"    ← رقاقةُ التصفية الأولى؛ يقبل «القطاع» و«التخصص».
--   fields."الموقع"    ← رقاقةُ التصفية الثانية؛ يقبل «مكان العمل» و«المكان».
--   fields."النوع"     ← دائم/مؤقت/عن بُعد بلفظ الإعلان؛ يقبل «طبيعة العمل».
--   fields."الراتب"    ← كما كُتب («٦٠٠٠ ج م» أو «حسب المقابلة»)، ولا يُحوَّل ولا
--                        يُقدَّر، وإن تُرك فارغًا لم يظهر سطرُه.
--   fields."الخبرة"    ← «سنتان» أو «لا يشترط»؛ يقبل «السن».
--   fields."عدد المطلوب" ← سطرٌ نصي: «٣ مهندسين» يبقى كما هو.
--   fields."التقديم"   ← طريقةُ التسليم كما كتبها المعلن (عنوان/بريد/هاتف).
--   fields."آخر موعد"  ← تاريخٌ «2026-11-05» أو «٥/١١/٢٠٢٦»؛ عنده تُطوى الفرصةُ في
--                        مجموعة «انقضت مهلتها». يومُ الموعد نفسِه ما زالت تُقبل.
--                        غابَ بقيت حيّةً بلا يوم، ولا يُفتَرَض لها إغلاقٌ لم ينشره
--                        صاحبُه.
--   الرابط الخارجي     ← رابط التقديم، فيرسم التطبيق زرَّ «التقديم عبر الرابط»
--                        ويرسله إلى نظام التشغيل (مثل apps وchannels: بلا WebView
--                        ولا تتبّع). يقبله التطبيق أيضًا في fields."الرابط".
--
-- آمنة للتكرار (idempotent): تُوسّع قيد layout ليقبل 'jobs'، ثم تنشئ صفَّ القسم أو
-- تحدّثه. نفّذها في Supabase ← SQL Editor ← New query ← الصق ← Run (مشروع DeshoStore).

-- 1) قيد التخطيط: تُضاف 'jobs' إلى القائمة الحاضرة، مع بقاء ما فيها.
alter table public.sections drop constraint if exists sections_layout_check;
alter table public.sections add constraint sections_layout_check check (
  layout in ('richArticle','list','cards','profiles','offers','ads','rates','directory',
             'jobs','apps','channels','prayer','weather','converter','calendar','memorials',
             'trains','results','schedule','campaigns','quran','tasks','matches','hadith')
);

-- 2) القسم: sort_order = 41 يضعه بعد أخبار القرية مباشرةً، فالفرصةُ خبرٌ سعيدٌ
--    يُقرأ كل يوم، لكنها لا تُزاحم «أحدث المنشورات» (التطبيق يُخرج تخطيط jobs من
--    المعاينة: مهلتُها تُطوى على شاشتها وحدها، والمعاينةُ لا تطوي شيئًا).
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, sort_order, enabled, show_on_home,
   notify_default, allow_breaking, items_source, note)
values
  ('jobs', 'فرص عمل',
   'إعلانات توظيفٍ ينشرها أصحابها: جهةٌ وموقعٌ وموعدٌ للتقديم', 'jobs', 'jobs', 'json', 41,
   true, true, true, false, 'admin',
   'كل فرصةٍ عنصرٌ هنا، والحقول كما كتبها المعلن حرفيًّا. لا تُنشر فرصةٌ قبل التحقق من صاحب العمل ورابط التقديم: التطبيق لا يضمن جهةً ولا يُقدّر راتبًا.')
on conflict (id) do update
  set title          = excluded.title,
      subtitle       = excluded.subtitle,
      icon           = excluded.icon,
      layout         = excluded.layout,
      source_kind    = excluded.source_kind,
      sort_order     = excluded.sort_order,
      notify_default = excluded.notify_default,
      allow_breaking = excluded.allow_breaking,
      items_source   = excluded.items_source,
      note           = excluded.note;

-- 3) لا عناصر: هذا القسم يبدأ فارغًا عن قصد (انظر الرأس). أولُ فرصةٍ تُكتب من
--    اللوحة، أو من نسخة هذا القالب بعد إبدال كل قيمٍ بما نُشر فعلًا:
--
-- insert into public.items
--   (section_id, slug, title, subtitle, body, image, link, source_name, source_url,
--    tags, fields, status, sort_order, published_at)
-- values
--   ('jobs', 'job-slug', 'مطلوب …', null, 'تفاصيل الإعلان', null,
--    'https://example.com/apply', 'اسم المعلن', 'https://example.com',
--    '[]'::jsonb,
--    '{"الجهة": "…", "المجال": "…", "الموقع": "…", "النوع": "…",
--     "الراتب": "…", "الخبرة": "…", "التقديم": "…", "آخر موعد": "2026-11-05"}'::jsonb,
--    'published', 0, now());

-- 4) تحقّقٍ مطبوع: نتائج في اللوح ورسائل في Running.
do $$
declare
  sect    record;
  seeded  integer;
  r       record;
  raw     text;
  folded  text;
  parsed  date;
  url     text;
  fields_ text[] := array['آخر موعد','الموعد الأخير','يغلق'];
  k       text;
begin
  select layout, source_kind, items_source into sect
    from public.sections where id = 'jobs';

  if not found then
    raise warning 'WARNING: قسم jobs غير موجود — لن يظهر في درج التطبيق ولا في index.json.';
  else
    if sect.layout = 'jobs' then
      raise notice 'NOTICE: قسم فرص عمل جاهز (layout=jobs, kind=%, items=%).',
        sect.source_kind, sect.items_source;
    else
      raise warning 'WARNING: تخطيط القسم «%» لا jobs — سيرسمه التطبيق قائمةَ أخبار عادية.',
        sect.layout;
    end if;
    if sect.source_kind <> 'json' or sect.items_source <> 'admin' then
      raise warning 'WARNING: القسم غير مُدار من اللوحة (kind=%, items=%) — لن يكتب الناشر ملفَّ عناصره.',
        sect.source_kind, sect.items_source;
    end if;
  end if;

  select count(*) into seeded from public.items
   where section_id = 'jobs' and status = 'published';

  if seeded = 0 then
    raise notice 'NOTICE: لا فرصة منشورة بعد — وهذا مقصود: البذرة لا تخترع جهةً ولا وظيفة. أضف أول فرصة من اللوحة.';
  else
    raise notice 'NOTICE: % فرصة منشورة، ويكتبها الناشر في data/sections/jobs.json.', seeded;
  end if;

  for r in select slug, title, link, fields from public.items
            where section_id = 'jobs' and status = 'published' loop

    -- (أ) الموعد: إن لم يُقرأ بقيت الفرصةُ معروضةً إلى أبدٍ لا آخرَ له.
    raw := null;
    foreach k in array fields_ loop
      if raw is null then
        raw := nullif(btrim(coalesce(r.fields->>k, '')), '');
      end if;
    end loop;

    if raw is null then
      raise notice 'NOTICE: فرصة «%» بلا «آخر موعد»: تبقى حيّةً بلا يوم إغلاق.', r.title;
    else
      folded := translate(raw, '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789');
      begin
        if folded ~ '^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}$' then
          parsed := to_date(folded, 'YYYY-MM-DD');
        elsif folded ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' then
          parsed := to_date(folded, 'DD/MM/YYYY');
        else
          parsed := null;
        end if;
      exception when others then
        parsed := null;
      end;

      if parsed is null then
        raise warning 'WARNING: موعد «%» في فرصة «%» لا يقرؤه التطبيق (استعمل 2026-11-05 أو 5/11/2026)، فترى الفرصةُ أنها لا تنقضي.', raw, r.title;
      elsif parsed < current_date then
        raise notice 'NOTICE: فرصة «%» انقضت في %: تُطوى تحت «انقضت مهلتها»، وأرشِفها إن أردتها أن تختفي.', r.title, parsed;
      end if;
    end if;

    -- (ب) التقديم: بلا رابطٍ صالح لا زرَّ، ويبقى سطرُ «التقديم» وصفًا يُقرأ.
    url := coalesce(nullif(btrim(coalesce(r.link, '')), ''),
                    nullif(btrim(coalesce(r.fields->>'الرابط', '')), ''));
    if url is null then
      raise notice 'NOTICE: فرصة «%» بلا رابط تقديم: بطاقتُها تُعرض بلا زرِّ «التقديم عبر الرابط».', r.title;
    elsif url !~ '^https?://' then
      raise warning 'WARNING: رابط فرصة «%» ليس http(s) فلا يُفتح: «%».', r.title, url;
    end if;
  end loop;
end
$$;

-- قراءةٌ أخيرة لحالة القسم وعناصره (لا تكتب شيئًا).
select s.id, s.title, s.layout, s.icon, s.sort_order, s.enabled, s.show_on_home,
       s.notify_default, s.allow_breaking, s.items_source,
       (select count(*) from public.items i
         where i.section_id = s.id and i.status = 'published') as published_items
  from public.sections s
 where s.id = 'jobs';

select i.slug, i.title,
       coalesce(i.fields->>'الجهة', i.fields->>'الشركة')    as employer,
       coalesce(i.fields->>'المجال', i.fields->>'القطاع')   as sector,
       i.fields->>'الموقع'                                  as place,
       coalesce(i.fields->>'آخر موعد', i.fields->>'يغلق')   as deadline,
       i.link, i.status
  from public.items i
 where i.section_id = 'jobs'
 order by i.published_at desc nulls last, i.sort_order desc;
