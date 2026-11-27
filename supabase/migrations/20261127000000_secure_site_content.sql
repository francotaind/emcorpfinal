-- Secure the admin editor.
--
-- Before: writes to public.site_content were allowed for any request that
-- sent a shared "x-admin-secret" header. That secret was shipped in the
-- public index.html, so anyone could edit the live site.
--
-- After: anyone may read site_content; only a signed-in Supabase Auth user
-- listed in public.site_admins may insert, update or delete it.
--
-- Safe to run more than once. Run it in the Supabase SQL editor for the
-- project, or with `supabase db push`.

begin;

-- 1. Who is an admin. Rows are added by hand (see README / PR notes).
create table if not exists public.site_admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.site_admins enable row level security;
-- No policies on purpose: browsers cannot read or change this list.
-- Manage it from the dashboard / SQL editor.
revoke all on public.site_admins from anon, authenticated;

-- 2. Helper the policies and the page use. SECURITY DEFINER so it can read
-- site_admins even though that table is closed to the API roles.
create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.site_admins a where a.user_id = auth.uid()
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated;

-- 3. Remove every existing policy on site_content, including the old
-- header-secret write policy, whatever it was named.
do $$
declare
  pol record;
begin
  for pol in
    select policyname
    from pg_policies
    where schemaname = 'public' and tablename = 'site_content'
  loop
    execute format('drop policy %I on public.site_content', pol.policyname);
  end loop;
end
$$;

alter table public.site_content enable row level security;

-- 4. New policies.
create policy "Anyone can read site content"
  on public.site_content
  for select
  to anon, authenticated
  using (true);

create policy "Admins can insert site content"
  on public.site_content
  for insert
  to authenticated
  with check ((select public.is_site_admin()));

create policy "Admins can update site content"
  on public.site_content
  for update
  to authenticated
  using ((select public.is_site_admin()))
  with check ((select public.is_site_admin()));

create policy "Admins can delete site content"
  on public.site_content
  for delete
  to authenticated
  using ((select public.is_site_admin()));

-- Visitors only ever need to read.
revoke insert, update, delete, truncate on public.site_content from anon;
grant select on public.site_content to anon, authenticated;
grant insert, update, delete on public.site_content to authenticated;

commit;
