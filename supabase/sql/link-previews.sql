-- ربط لوحة التحكم والتطبيق باسم الصفحة الحقيقي بدل عنوان URL المُشفَّر.
-- آمن للتكرار (idempotent): لا يحذف جدولًا ولا بيانات، ويمكن تنفيذ مرتين.
-- نفّذه في Supabase ← SQL Editor ← New query ← الصق ← Run (مشروع DeshoStore).

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

-- الكتابة يفعلها الناشر بمفتاح service_role (يتجاوز RLS)، والقراءة للمدراء
-- لتعرض معاينة اللوحة الاسم نفسه الذي سيُنشر.
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

-- تحقّق (قراءة فقط): صف واحد بـ relrowsecurity = t، والجداول فارغة حتى أول نشر فيه روابط.
select c.relname, c.relrowsecurity,
       (select count(*) from public.link_previews) as rows,
       (select count(*) from pg_policies where schemaname = 'public' and tablename = 'link_previews') as policies
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relname = 'link_previews';
