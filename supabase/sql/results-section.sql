-- قسم «نتائج الامتحانات»: لوحة إعلانات لكل مرحلة ومحافظة، وبحث الطالب برقم جلوسه.
--
-- لماذا لا يجلب التطبيق النتيجة من البوابة الرسمية؟ لأنه لا يستطيع (فُحص في ٢٠٢٦-١٠-١٩):
--   g12.emis.gov.eg        نموذج ASP.NET يريد __RequestVerificationToken وجلسة؛ ورقم وهمي
--                          رجَع 302 إلى /Error/400 (صفحة HTML، لا JSON).
--   prepnatega.emis.gov.eg لم يُستطَع الوصول إليه من هذا الجهاز، ونصّه أن النتائج تظهر «تباعًا».
--   مديريات المحافظات       كل محافظة نظام: gizaedu.net (جافاسكريبت)، sohagnatiga.somee.com
--                          (استضافة مجانية) — عشرات الواجهات الهشّة تسقط عند أول تحديث لهم.
--   natiga.azhar.eg        بحث بالرقم القومي لا برقم الجلوس.
--   المجمِّعات الإخبارية    مقال فيه رابط البوابة، لا قاعدة بيانات.
-- ولا يوجد أي JSON API رسمي ولا مجموعة بيانات مفتوحة على data.gov.eg أو moe.gov.eg.
-- فالبديل الوحيد الممكن والأمين: كشف النتيجة الرسمي يصل إلى الناشر (مدرسة/مديرية)، فيُحمَّل
-- إلى هذا الجدول، فيعمل البحث فورًا — بلا كرون ولا انتظار جولة نشر.
--
-- قرار صريح خلاف الطلب الحرفي: البحث برقم الجلوس + اسم الطالب، لا برقم الجلوس وحده.
-- المفتاح الذي سيحمله التطبيق عامّ (anon)، فلو اكتُفي برقم الجلوس لصار استخراج كل نتائج
-- المحافظة عدَّ أرقام. الاسم الذي يعرفه الطالب عن نفسه لا يسأله شيئًا، ويمنع ذلك.
--
-- الخصوصية: لا نتيجة طالب تُنشر على GitHub Pages (الملفات هناك عامةٌ للأبد، وبيانات قُصّر).
-- تبقى خلف RLS، بلا أي سياسة لـ anon على الجدولين: السبيل الوحيد صفٌّ واحد تطابق رقمه
-- واسمه معًا عبر lookup_result. والمصدر يبقى المدرسة، فلا يدّعي التطبيق أنه جهة اعتداد.
--
-- آمن للتكرار: يوسّع قيدًا، وينشئ جداول ودوال، ويزكّي صفّ القسم وثابت الاختبار.
-- نفّذه في Supabase ← SQL Editor ← New query ← الصق ← Run (مشروع DeshoStore).
-- ثابت '__test__' مقصود ولا يُمسح: عليه يعمل tools/verify-results.mjs، ولا يظهر للقارئ
-- لأنّ عناصر القسم تُقرأ من جدول items لا من exam_stages.

-- 1) قيد التخطيط: بلا توسيعه ترفض القاعدة حفظ القسم الجديد.
--    الأسماء نفسها في trains-section وalmanac-sections وcalendar-section وغيرها.
alter table public.sections drop constraint if exists sections_layout_check;
alter table public.sections add constraint sections_layout_check check (
  layout in ('richArticle','list','cards','profiles','offers','ads','rates','directory',
             'apps','channels','prayer','weather','converter','calendar','memorials','trains',
             'results','schedule','campaigns','quran','tasks','matches','hadith')
);

-- 2) الامتحان: سطر لكل (مرحلة × محافظة × عام × دور). published هي ما يفرق
--    «لم تُعتمد بعد» عن «ابحث الآن»؛ فلا تُقلَب إلا بعد وصول الكشف.
create table if not exists public.exam_stages (
  exam_id      text primary key check (exam_id ~ '^[A-Za-z0-9_][A-Za-z0-9_.-]{2,60}$'),
  stage        text not null check (btrim(stage) <> ''),
  gov          text not null check (btrim(gov) <> ''),
  year         integer not null check (year between 2000 and 2100),
  term         text not null check (btrim(term) <> ''),
  official_url text,
  published    boolean not null default false,
  announced_on date,
  note         text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists exam_stages_gov_idx on public.exam_stages (gov, year desc);

-- 3) النتائج: صفٌّ لكل طالب في امتحان. المفتاح مركّب، فلا يُخلط رقم جلوس متكرّر بين
--    امتحانين، ومقبوض رقم مكرّر داخل الامتحان الواحد على مستوى الإدخال نفسه.
create table if not exists public.exam_results (
  exam_id   text not null references public.exam_stages(exam_id) on delete cascade,
  seat_no   text not null check (seat_no ~ '^[0-9]{4,20}$'),
  name_ar   text not null check (btrim(name_ar) <> ''),
  name_norm text not null default '',
  total     numeric check (total is null or (total >= 0 and total <= 1000)),
  ratio     numeric check (ratio is null or (ratio >= 0 and ratio <= 100)),
  status    text not null default 'ناجح'
            check (status in ('ناجح','دور ثان','راسب','لم يحضر')),
  imported_at timestamptz not null default now(),
  primary key (exam_id, seat_no)
);

-- البحث برقم الجلوس وحده، وهو مسار التطبيق كله.
create index if not exists exam_results_seat_idx on public.exam_results (seat_no);

drop trigger if exists exam_stages_touch on public.exam_stages;
create trigger exam_stages_touch before update on public.exam_stages
  for each row execute function public.touch_updated_at();

-- 4) اسم الطالب يُخزَّن مطويًّا، فتطابق البحث لا يتعلّق بكتابة الكاشف (أ/ا، ة/ه، التشكيل).
create or replace function public.normalize_ar(raw text)
returns text
language sql
stable
set search_path = public
as $$
  select btrim(
    lower(
      translate(
        regexp_replace(coalesce(raw, ''), E'[ـً-ْ]', '', 'g'),
        'أإآٱىة', 'اااايه'
      )
    )
  );
$$;

-- يُشتق عمود name_norm من name_ar عند الإدخال، فلا يُطلب من الكاشف تعبئته.
create or replace function public.exam_results_fill_norm()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.name_norm := public.normalize_ar(new.name_ar);
  return new;
end;
$$;

drop trigger if exists exam_results_norm on public.exam_results;
create trigger exam_results_norm before insert or update of name_ar on public.exam_results
  for each row execute function public.exam_results_fill_norm();

-- 5) الباب العام الوحيد: صفٌّ واحد، برقم صحيح واسم يطابق أوله أربعة أحرف فأكثر.
--    STABLE لأن PostgREST لا يقبل GET إلا على دالة مستقرة، وطبقة الشبكة في التطبيق GET فقط.
--    لا تُرجع عدد الصفوف ولا قائمة: لا يوجد سبيل لعدّ النتائج من الباب العام.
create or replace function public.lookup_result(p_seat text, p_name text)
returns table (
  exam_id text, stage text, gov text, year integer, term text,
  seat_no text, name_ar text, total numeric, ratio numeric, status text,
  official_url text, announced_on date
)
language sql
stable
security definer
set search_path = public
as $$
  select s.exam_id, s.stage, s.gov, s.year, s.term,
         r.seat_no, r.name_ar, r.total, r.ratio, r.status,
         s.official_url, s.announced_on
    from public.exam_results r
    join public.exam_stages s using (exam_id)
   where s.published
     and r.seat_no = btrim(coalesce(p_seat, ''))
     and char_length(public.normalize_ar(coalesce(p_name, ''))) >= 4
     and position(public.normalize_ar(coalesce(p_name, '')) in r.name_norm) > 0
   order by s.year desc, s.exam_id
   limit 5;
$$;

-- 6) RLS: مفعّل، والمدخل الوحيد للقراءة العامة هو الدالة أعلاه.
alter table public.exam_stages enable row level security;
alter table public.exam_results enable row level security;

drop policy if exists "exam_stages: admins read" on public.exam_stages;
create policy "exam_stages: admins read"
  on public.exam_stages for select to authenticated using (public.is_admin());
drop policy if exists "exam_stages: admins write" on public.exam_stages;
create policy "exam_stages: admins write"
  on public.exam_stages for insert to authenticated with check (public.is_admin());
drop policy if exists "exam_stages: admins update" on public.exam_stages;
create policy "exam_stages: admins update"
  on public.exam_stages for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "exam_stages: admins delete" on public.exam_stages;
create policy "exam_stages: admins delete"
  on public.exam_stages for delete to authenticated using (public.is_admin());

drop policy if exists "exam_results: admins read" on public.exam_results;
create policy "exam_results: admins read"
  on public.exam_results for select to authenticated using (public.is_admin());
drop policy if exists "exam_results: admins write" on public.exam_results;
create policy "exam_results: admins write"
  on public.exam_results for insert to authenticated with check (public.is_admin());
drop policy if exists "exam_results: admins update" on public.exam_results;
create policy "exam_results: admins update"
  on public.exam_results for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "exam_results: admins delete" on public.exam_results;
create policy "exam_results: admins delete"
  on public.exam_results for delete to authenticated using (public.is_admin());

-- لا سياسة لـ anon — ويُمنع الامتياز نفسه صراحةً، فلا اعتماد على أن RLS وحده يكفي.
revoke all on public.exam_stages from anon;
revoke all on public.exam_results from anon;
grant execute on function public.normalize_ar(text) to anon;
grant execute on function public.lookup_result(text, text) to anon;

-- 7) القسم: ترتيبه ٨٦ يلي مواعيد القطارات (٨٥) ويسبق العروض (٩٠)، فهو خدمة موسمية ينتظرها بيت.
insert into public.sections
  (id, title, subtitle, icon, layout, source_kind, sort_order, enabled, show_on_home,
   notify_default, allow_breaking, items_source, note)
values
  ('results', 'نتائج الامتحانات',
   'ابحث برقم جلوسك، واعرف متى تعتمد نتيجة كل مرحلة',
   'school', 'results', 'json', 86,
   true, true, true, false, 'admin',
   'كل عنصر إعلان مرحلة/محافظة: العنوان اسم المرحلة والمحافظة، و«التاريخ كما يظهر» تاريخ '
   || 'الاعتماد، وفي الحقول: المرحلة، المحافظة، العام، الدور، الحالة (لم تُعتمد/اعتمدت/دور ثان)، '
   || 'وباب النتيجة الرسمي في الرابط الخارجي. نتائج الطلبة نفسها لا تُنشر هنا ولا على Pages: '
   || 'تُحمَّل من كشف المدرسة إلى جدول exam_results، فيعمل البحث برقم الجلوس واسم الطالب فورًا.')
on conflict (id) do update
  set title        = excluded.title,
      subtitle     = excluded.subtitle,
      icon         = excluded.icon,
      layout       = excluded.layout,
      source_kind  = excluded.source_kind,
      sort_order   = excluded.sort_order,
      enabled      = excluded.enabled,
      show_on_home = excluded.show_on_home,
      items_source = excluded.items_source,
      note         = excluded.note;

-- 8) ثابت الاختبار: أسماء وأرقام وهمية واضحة، عليه يقيس المِشْبَك أن الباب العام لا يتسرّب.
insert into public.exam_stages (exam_id, stage, gov, year, term, official_url, published, note)
values ('__test__', 'مرحلة اختبار', 'تجربة', 2026, 'اختبار', null, true,
        'ثابت لـ tools/verify-results.mjs — لا يظهر للقارئ؛ فبطاقات القسم تُقرأ من items')
on conflict (exam_id) do update
  set published = true, note = excluded.note;

insert into public.exam_results (exam_id, seat_no, name_ar, total, status)
values
  ('__test__', '00000001', 'طالب تجربة أول',  260.5, 'ناجح'),
  ('__test__', '00000002', 'طالبة تجربة ثانية', 199.0, 'دور ثان')
on conflict (exam_id, seat_no) do update
  set name_ar = excluded.name_ar,
      total   = excluded.total,
      status  = excluded.status;

-- 9) لا يلتقط PostgREST الجدول والدالة الجديدين حتى تُحمَّل خطته من جديد.
select pg_notify('pgrst', 'reload schema');

-- 10) تدقيق (قراءة فقط): WARNING عند خلل في الباب العام، NOTICE عند السلامة.
do $$
declare
  layout_def   text;
  anon_tables  integer;
  anon_policies integer;
  sec          public.sections%rowtype;
  fx_rows      integer;
  fx_norm_ok   integer;
  leaks        integer;
begin
  select pg_get_constraintdef(oid) into layout_def
    from pg_constraint where conname = 'sections_layout_check';
  select * into sec from public.sections where id = 'results';

  -- كم جدولًا للنتائج مفتوح لـ anon بسياسة؟ الجواب الصحيح: صفر.
  select count(*) into anon_tables
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relname in ('exam_results','exam_stages')
     and c.relrowsecurity;
  select count(*) into anon_policies
    from pg_policy p
    join pg_class c on c.oid = p.polrelid
    join pg_roles r on r.oid = any (p.polroles::oid[])
   where c.relname in ('exam_results','exam_stages') and r.rolname = 'anon';

  select count(*) into fx_rows from public.exam_results where exam_id = '__test__';
  select count(*) into fx_norm_ok from public.exam_results
    where exam_id = '__test__' and name_norm = public.normalize_ar(name_ar);
  select count(*) into leaks from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in ('lookup_result','normalize_ar');

  if layout_def like '%results%' then
    raise notice 'NOTICE: القيد قبِل results، فاللوحة تحفظ القسم بلا رفض.';
  else
    raise warning 'WARNING: لم يُوسَّع قيد التخطيط: %', coalesce(layout_def, 'لا قيد');
  end if;

  if sec.id is null then
    raise warning 'WARNING: لا صف results في sections — لن يظهر القسم في التطبيق.';
  else
    raise notice 'NOTICE: قسم النتائج جاهز: layout=%, icon=%, sort=%, notify=%',
      sec.layout, sec.icon, sec.sort_order, sec.notify_default;
  end if;

  if anon_tables = 2 then
    raise notice 'NOTICE: RLS مفعّل على الجدولين.';
  else
    raise warning 'WARNING: RLS غير مفعّل على كل جداول النتائج (% من ٢) — البيانات مكشوفة.', anon_tables;
  end if;

  if anon_policies = 0 then
    raise notice 'NOTICE: لا سياسة قراءة لـ anon على جداول النتائج؛ الباب الوحيد lookup_result.';
  else
    raise warning 'WARNING: فيه % سياسة لـ anon على جداول النتائج — أزلها، فهي تسرب كل كشف الطالب.', anon_policies;
  end if;

  if leaks = 2 then
    raise notice 'NOTICE: الدالتان موجودتان (normalize_ar وlookup_result)؛ grant anon عليهما هو ما يسمح بالتطبيق أن يسأل.';
  else
    raise warning 'WARNING: تنقص دالة من الباب العام؛ البحث لن يعمل.';
  end if;

  if fx_rows = 2 and fx_norm_ok = 2 then
    raise notice 'NOTICE: ثابت الاختبار مكتمل ومطويّ الاسم؛ شغّل node tools/verify-results.mjs.';
  else
    raise warning 'WARNING: ثابت الاختبار ناقص (% صفوف، % أسماء مطويّة) — المِشْبَك لن يقيس شيئًا.', fx_rows, fx_norm_ok;
  end if;
end $$;

-- 11) ما سيراه التطبيق (قراءة فقط): الامتحانات المتاحة للبحث الآن.
select exam_id, stage, gov, year, term, published, announced_on,
       (select count(*) from public.exam_results r where r.exam_id = s.exam_id) as نتائج
  from public.exam_stages s
 order by published desc, year desc, gov;
