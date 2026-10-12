-- Migration: Profiles table and username lookup for authentication
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text unique not null,
  email text not null,
  created_at timestamptz not null default now()
);

-- Case-insensitive index for fast username lookups
create unique index if not exists idx_profiles_lower_username on public.profiles (lower(username));

alter table public.profiles enable row level security;

-- Policies:
-- Allow anyone to check username existence and look up email for login
drop policy if exists "Allow username lookup" on public.profiles;
create policy "Allow username lookup" on public.profiles
  for select using (true);

-- Allow authenticated users to insert their own profile
drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile" on public.profiles
  for insert with check (auth.uid() = id);

-- Allow authenticated users to update their own profile
drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile" on public.profiles
  for update using (auth.uid() = id);

-- RPC for secure email lookup by username
create or replace function public.get_email_by_username(p_username text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
begin
  select email into v_email
    from public.profiles
   where lower(username) = lower(trim(p_username))
   limit 1;
  return v_email;
end;
$$;

-- Trigger to automatically create profile on auth.users insert if user_metadata has username
create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text;
begin
  v_username := coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1));
  insert into public.profiles (id, username, email)
  values (new.id, lower(trim(v_username)), lower(trim(new.email)))
  on conflict (id) do update
    set email = excluded.email,
        username = coalesce(public.profiles.username, excluded.username);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
  after insert on auth.users
  for each row execute function public.handle_new_user_profile();
