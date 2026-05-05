-- Required profiles columns
alter table public.profiles
  add column if not exists display_name text,
  add column if not exists photo_url text,
  add column if not exists credits integer not null default 1000,
  add column if not exists wins integer not null default 0,
  add column if not exists losses integer not null default 0,
  add column if not exists games_played integer not null default 0,
  add column if not exists updated_at timestamptz not null default now();

-- RLS policies: authenticated user can read/update only own profile
alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
for select to authenticated
using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
for update to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

-- Chat table used by duel_mode.dart
create table if not exists public.duel_chat_messages (
  id uuid primary key default gen_random_uuid(),
  game_id text not null references public.duel_games(room_code) on delete cascade,
  sender_id uuid not null,
  sender_name text not null,
  text text not null,
  created_at timestamptz not null default now()
);
