-- ─────────────────────────────────────────────────────────────────────────────
-- قرية أبو بدوي — تهيئة Supabase (خطة Free): المصدر الوحيد لكل محتوى التطبيق
--
-- ماذا يغطي هذا الملف؟
--   الإعدادات العامة، الأقسام، العناصر (نص + وسائط)، القوانين، أسعار العملات
--   والذهب، مكتبة الوسائط، سجل النشر، وصلاحيات المدراء (RLS).
--   التطبيق لا يقرأ من Supabase إطلاقًا: يعمل GitHub Action (publish.mjs) بتوليد
--   ملفات data/*.json من هذه الجداول ثم يدفعها إلى GitHub Pages.
--
-- خطوات الاستخدام:
--   1) Supabase ← SQL Editor ← New query ← الصق هذا الملف كله ← Run.
--      (لا ينشئ مشروعًا جديدًا إذا لم يتوفر رصيد مشاريع؛ راجع README.)
--   2) عدّل بريد المدير في السطر الذي يبدأ بـ  insert into public.admin_emails
--      — أضف كل بريد محرر في سطر مستقل.
--   3) أنشئ حسابات المدراء: Authentication ← Users ← Add user
--      (Email/Password + Auto Confirm)، ثم استخدمها في dashboard.html.
--   4) نفّذ supabase/sql/seed-content.sql بعد هذا الملف: يحوّل المحتوى المنشور حاليًا
--      (web/data/*.json) إلى صفوف، فلا تفقد أي شيء عند أول نشر.
--      توليد نسخة منه مستقبلًا: node tools/gen-seed-sql.mjs
--   5) أضف السرّين في GitHub ← Settings ← Secrets and variables ← Actions:
--      SUPABASE_URL و SUPABASE_SERVICE_KEY (مفتاح service_role، لا يُطبع أبدًا).
--
-- ملاحظات أمان:
--   • كل الجداول مغلقة بـ RLS على قائمة المدراء فقط؛ لا وصول لـ anon.
--   • مستودع media عام القراءة لأن التطبيق يفتح الرابط المباشر للصورة/المقطع.
--   • التكرار آمن: كل العبارات idempotent، ولا يوجد أي drop for data أو delete.
-- ─────────────────────────────────────────────────────────────────────────────

-- 0) امتدادات (gen_random_uuid)
create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1) قائمة المدراء + دالة التحقق
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.admin_emails (
  email      text primary key,
  label      text,
  added_at   timestamptz not null default now()
);

-- ⚠️ السطر الوحيد الذي يجب تعديله قبل التنفيذ
insert into public.admin_emails (email, label) values ('admin@abubadawy.local', 'المدير')
  on conflict (email) do nothing;

-- الدالة تُنشأ قبل أي سياسة تستخدمها، وإلا فشل التنفيذ عند create policy.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select true
       from public.admin_emails a
      where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))),
    false
  );
$$;

grant execute on function public.is_admin() to authenticated, anon;

alter table public.admin_emails enable row level security;

drop policy if exists "admin_emails: admins read" on public.admin_emails;
create policy "admin_emails: admins read"
  on public.admin_emails for select
  to authenticated
  using (public.is_admin());

-- allows adding/removing editors from the dashboard's settings panel
drop policy if exists "admin_emails: admins insert" on public.admin_emails;
create policy "admin_emails: admins insert"
  on public.admin_emails for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists "admin_emails: admins delete" on public.admin_emails;
create policy "admin_emails: admins delete"
  on public.admin_emails for delete
  to authenticated
  using (public.is_admin());

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) trigger موحّد لتحديث updated_at
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3) الإعدادات العامة: صف واحد يطابق كتل index.json
--    brand/digest/prices/location ملفات jsonb حتى تُضاف حقول جديدة للتطبيق
--    دون هجرة جدول.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.app_settings (
  id             integer      primary key default 1 check (id = 1),
  schema_version integer      not null default 1,
  brand          jsonb        not null default '{}'::jsonb,
  digest         jsonb        not null default '{}'::jsonb,
  prices         jsonb        not null default '{}'::jsonb,
  -- موقع القرية لإحداثيات المواقيت والأرصاد: {name,latitude,longitude,timezone}
  location       jsonb        not null default '{}'::jsonb,
  -- نص عربي قصير يظهر شريطًا في التطبيق؛ null = لا إخطار
  notice         text,
  updated_at     timestamptz  not null default now()
);

insert into public.app_settings (id) values (1)
  on conflict (id) do nothing;

alter table public.app_settings enable row level security;

drop policy if exists "app_settings: admins read" on public.app_settings;
create policy "app_settings: admins read"
  on public.app_settings for select to authenticated using (public.is_admin());

drop policy if exists "app_settings: admins update" on public.app_settings;
create policy "app_settings: admins update"
  on public.app_settings for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists "app_settings: admins insert" on public.app_settings;
create policy "app_settings: admins insert"
  on public.app_settings for insert to authenticated with check (public.is_admin());

drop trigger if exists app_settings_touch on public.app_settings;
create trigger app_settings_touch before update on public.app_settings
  for each row execute function public.touch_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 4) الأقسام: ما يقرأه التطبيق من index.json
--    القيم مقيدة بما يعرفه الكود فعلًا:
--      layout    ← enum Layout في data/model/Models.kt
--      source_kind ← enum SourceKind
--      icon      ← sectionIcon() في ui/common/SectionIcons.kt
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.sections (
  id             text        primary key check (id ~ '^[a-z][a-z0-9_]{1,40}$'),
  title          text        not null check (btrim(title) <> ''),
  subtitle       text,
  icon           text        not null default 'article',
  layout         text        not null default 'list'
                 check (layout in ('richArticle','list','cards','profiles',
                                   'offers','ads','rates','directory','apps','channels',
                                   'prayer','weather','converter','calendar','memorials','trains')),
  source_kind    text        not null default 'json'
                 check (source_kind in ('json','rss','html','fx','gold','inline',
                                        'prayer','weather','converter','calendar')),
  -- rss/html: رابط التغذية. json: اتركه فارغًا ليكتبه الناشر في data/sections/<id>.json
  feed_url       text,
  item_selector  text,
  headers        jsonb       not null default '{}'::jsonb,
  sort_order     integer     not null default 100,
  enabled        boolean     not null default true,
  show_on_home   boolean     not null default true,
  notify_default boolean     not null default false,
  allow_breaking boolean     not null default true,
  -- admin: عناصره من جدول items. file: ملف JSON يُحرَّر يدويًا ولا يلمسه الناشر.
  items_source   text        not null default 'admin'
                 check (items_source in ('admin','file')),
  -- صورة اختيارية من لوحة التحكم؛ ينشرها publish.mjs في index.json باسم image
  cover_image    text,
  note           text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index if not exists sections_order_idx on public.sections (sort_order);

alter table public.sections enable row level security;

drop policy if exists "sections: admins read" on public.sections;
create policy "sections: admins read"
  on public.sections for select to authenticated using (public.is_admin());
drop policy if exists "sections: admins insert" on public.sections;
create policy "sections: admins insert"
  on public.sections for insert to authenticated with check (public.is_admin());
drop policy if exists "sections: admins update" on public.sections;
create policy "sections: admins update"
  on public.sections for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "sections: admins delete" on public.sections;
create policy "sections: admins delete"
  on public.sections for delete to authenticated using (public.is_admin());

drop trigger if exists sections_touch on public.sections;
create trigger sections_touch before update on public.sections
  for each row execute function public.touch_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 5) العناصر: كل بطاقة يراها التطبيق داخل قسم
--    attachments: jsonb على شكل [{"type","url","poster","label","duration","path"}]
--    وهو عقد data-ab-attachments نفسه الذي تقرأه صفحة الويب والتطبيق.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.items (
  id            uuid        primary key default gen_random_uuid(),
  section_id    text        not null references public.sections (id) on delete cascade,
  -- معرّف ثابت يظهر في JSON؛ اتركه فارغًا فيُشتق من id
  slug          text,
  title         text        not null check (btrim(title) <> ''),
  subtitle      text,
  body          text,
  image         text,
  image_credit  text,
  link          text,
  source_name   text,
  source_url    text,
  tags          jsonb       not null default '[]'::jsonb,
  fields        jsonb       not null default '{}'::jsonb,
  attachments   jsonb       not null default '[]'::jsonb,
  pinned        boolean     not null default false,
  breaking      boolean     not null default false,
  status        text        not null default 'draft'
                check (status in ('draft','scheduled','published','archived')),
  -- تاريخ العرض كما يكتبه المحرر: "2026-09-27" أو "1950" أو "شتاء 1978".
  -- يبقى نصًا لأن التطبيق يعرضه ويسجل به الترتيب دون أن يحسبه.
  event_date    text,
  -- وقت النشر المجدول (schedule)؛ published_at تُضبط عندما يصبح published
  publish_at    timestamptz,
  published_at  timestamptz,
  sort_order    integer     not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  created_by    uuid references auth.users (id) on delete set null
);

create index if not exists items_section_status_idx
  on public.items (section_id, status, sort_order desc, published_at desc);
create index if not exists items_updated_idx on public.items (updated_at desc);
create index if not exists items_scheduled_idx
  on public.items (publish_at) where status = 'scheduled';

alter table public.items enable row level security;

drop policy if exists "items: admins read" on public.items;
create policy "items: admins read"
  on public.items for select to authenticated using (public.is_admin());
drop policy if exists "items: admins insert" on public.items;
create policy "items: admins insert"
  on public.items for insert to authenticated with check (public.is_admin());
drop policy if exists "items: admins update" on public.items;
create policy "items: admins update"
  on public.items for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "items: admins delete" on public.items;
create policy "items: admins delete"
  on public.items for delete to authenticated using (public.is_admin());

drop trigger if exists items_touch on public.items;
create trigger items_touch before update on public.items
  for each row execute function public.touch_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 6) القوانين: سياسة الخصوصية وشروط الاستخدام
--    المتن يُنقّى أمنيًا وقت النشر (publish.mjs) لأن صفحة الويب تدرجه بـ innerHTML.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.legal_docs (
  key        text        primary key check (key in ('privacy','terms')),
  title      text        not null,
  body       text        not null default '',
  updated_at timestamptz not null default now()
);

alter table public.legal_docs enable row level security;

drop policy if exists "legal_docs: admins read" on public.legal_docs;
create policy "legal_docs: admins read"
  on public.legal_docs for select to authenticated using (public.is_admin());
drop policy if exists "legal_docs: admins write" on public.legal_docs;
create policy "legal_docs: admins write"
  on public.legal_docs for insert to authenticated with check (public.is_admin());
drop policy if exists "legal_docs: admins update" on public.legal_docs;
create policy "legal_docs: admins update"
  on public.legal_docs for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop trigger if exists legal_docs_touch on public.legal_docs;
create trigger legal_docs_touch before update on public.legal_docs
  for each row execute function public.touch_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 7) الأسعار: مصدر ملفي data/prices/fx.json و gold.json
--    قيمة النصية كما في العقد (value/change حرفيًا)، والتزامن الليلي يكتب هنا
--    عبر scripts/sync-prices.mjs بدل تعديل الملفات مباشرة.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.price_rows (
  id         uuid        primary key default gen_random_uuid(),
  kind       text        not null check (kind in ('fx','gold')),
  code       text        not null,
  name       text        not null,
  symbol     text,
  value      text        not null default '',
  change     text,
  sort_order integer     not null default 0,
  updated_at timestamptz not null default now(),
  unique (kind, code)
);

create index if not exists price_rows_kind_idx on public.price_rows (kind, sort_order);

alter table public.price_rows enable row level security;

drop policy if exists "price_rows: admins read" on public.price_rows;
create policy "price_rows: admins read"
  on public.price_rows for select to authenticated using (public.is_admin());
drop policy if exists "price_rows: admins write" on public.price_rows;
create policy "price_rows: admins write"
  on public.price_rows for insert to authenticated with check (public.is_admin());
drop policy if exists "price_rows: admins update" on public.price_rows;
create policy "price_rows: admins update"
  on public.price_rows for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "price_rows: admins delete" on public.price_rows;
create policy "price_rows: admins delete"
  on public.price_rows for delete to authenticated using (public.is_admin());

drop trigger if exists price_rows_touch on public.price_rows;
create trigger price_rows_touch before update on public.price_rows
  for each row execute function public.touch_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 8) مكتبة الوسائط: أرشفة ما رُفع إلى مستودع media وإعادة استخدامه
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.media_library (
  id          uuid        primary key default gen_random_uuid(),
  path        text        not null unique,
  url         text        not null,
  kind        text        not null check (kind in ('image','video','audio')),
  bytes       bigint      not null default 0,
  label       text,
  duration_seconds integer,
  poster_url  text,
  created_at  timestamptz not null default now(),
  created_by  uuid references auth.users (id) on delete set null
);

create index if not exists media_library_kind_idx on public.media_library (kind, created_at desc);

alter table public.media_library enable row level security;

drop policy if exists "media_library: admins read" on public.media_library;
create policy "media_library: admins read"
  on public.media_library for select to authenticated using (public.is_admin());
drop policy if exists "media_library: admins write" on public.media_library;
create policy "media_library: admins write"
  on public.media_library for insert to authenticated with check (public.is_admin());
drop policy if exists "media_library: admins update" on public.media_library;
create policy "media_library: admins update"
  on public.media_library for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "media_library: admins delete" on public.media_library;
create policy "media_library: admins delete"
  on public.media_library for delete to authenticated using (public.is_admin());

-- ─────────────────────────────────────────────────────────────────────────────
-- 9) سجل النشر: يكتبه publish.mjs بمفتاح service_role، وتقرأه اللوحة
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.publish_log (
  id            uuid        primary key default gen_random_uuid(),
  status        text        not null check (status in ('ok','partial','error')),
  message       text,
  sections_written integer  not null default 0,
  items_written    integer  not null default 0,
  commit_sha    text,
  created_at    timestamptz not null default now()
);

create index if not exists publish_log_recent_idx on public.publish_log (created_at desc);

alter table public.publish_log enable row level security;

drop policy if exists "publish_log: admins read" on public.publish_log;
create policy "publish_log: admins read"
  on public.publish_log for select to authenticated using (public.is_admin());
drop policy if exists "publish_log: admins write" on public.publish_log;
create policy "publish_log: admins write"
  on public.publish_log for insert to authenticated with check (public.is_admin());
drop policy if exists "publish_log: admins delete" on public.publish_log;
create policy "publish_log: admins delete"
  on public.publish_log for delete to authenticated using (public.is_admin());

-- ─────────────────────────────────────────────────────────────────────────────
-- 10) مستودع الوسائط: عام القراءة، مقيد النوع والحجم
--     خطة Free: 1 GB تخزين و 5 GB نقل شهريًا و 50 ألف مستخدم شهريًا.
--     الفيديو يلتهم النقل سريعًا؛ راجع README قبل رفع المقاطع.
-- ─────────────────────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'media',
  'media',
  true,
  26214400,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/avif', 'image/gif',
    'audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/ogg', 'audio/wav', 'audio/x-wav',
    'video/mp4', 'video/webm', 'video/quicktime'
  ]
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- RLS على storage.objects مُفعّلة أصلًا في Supabase، و`alter table` عليها يتطلب مالكها
-- (supabase_storage_admin) لا دور postgres الذي يعمل به محرر SQL — لذا لا نحاولها.

drop policy if exists "media: public reads" on storage.objects;
create policy "media: public reads"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'media');

drop policy if exists "media: admin uploads" on storage.objects;
create policy "media: admin uploads"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'media' and public.is_admin());

drop policy if exists "media: admin updates" on storage.objects;
create policy "media: admin updates"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'media' and public.is_admin())
  with check (bucket_id = 'media' and public.is_admin());

drop policy if exists "media: admin deletes" on storage.objects;
create policy "media: admin deletes"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'media' and public.is_admin());

-- ─────────────────────────────────────────────────────────────────────────────
-- 11) معاينات الروابط: يخزّنها publish.mjs حتى لا يُجلب الرابط مرتين
--     الكتابة هنا من المنفّذ بمفتاح service_role (يتجاوز RLS)، والقراءة للمدراء
--     لتطابق معاينة اللوحة ما سيُنشر فعلًا.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.link_previews (
  id          uuid        primary key default gen_random_uuid(),
  url         text        not null unique,
  host        text        not null,
  title       text,
  site_name   text,
  description text,
  image_url   text,
  icon_url    text,
  fetched_at  timestamptz not null default now(),
  failed_at   timestamptz,
  updated_at  timestamptz not null default now()
);

create index if not exists link_previews_host_idx on public.link_previews (host);

alter table public.link_previews enable row level security;

drop policy if exists "link_previews: admins read" on public.link_previews;
create policy "link_previews: admins read"
  on public.link_previews for select to authenticated using (public.is_admin());
drop policy if exists "link_previews: admins write" on public.link_previews;
create policy "link_previews: admins write"
  on public.link_previews for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop trigger if exists link_previews_touch on public.link_previews;
create trigger link_previews_touch
  before update on public.link_previews
  for each row execute function public.touch_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- تحقّق سريع بعد التنفيذ (Run منفصلًا، قراءة فقط):
--
--   select public.is_admin();                          -- false مع anon
--   select count(*) from public.sections;               -- 11 بعد seed-content.sql
--   select count(*) from public.items;                  -- عدد عناصر المحتوى الحالي
--   select count(*) from public.price_rows;              -- صفوف العملات + الذهب
--   select key, length(body) from public.legal_docs;     -- privacy + terms
--   select count(*) from public.link_previews;           -- 0 حتى أول نشر فيه روابط
--   select id, public, file_size_limit
--     from storage.buckets where id = 'media';           -- صف واحد، public = true
--
-- لو ظهر "new row violates row-level security policy" في اللوحة فمعناه أن
-- البريد المستخدم غير موجود في public.admin_emails.
-- ─────────────────────────────────────────────────────────────────────────────
