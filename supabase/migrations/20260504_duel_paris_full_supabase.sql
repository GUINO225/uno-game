-- Full Supabase migration for Duel / Paris
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Joueur',
  email text,
  photo_url text,
  credits bigint not null default 1000 check (credits >= 0),
  wins int not null default 0,
  losses int not null default 0,
  games_played int not null default 0,
  credits_won bigint not null default 0,
  score int not null default 0,
  card_avatar_rank text,
  card_avatar_suit text,
  is_registered boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.duel_games (
  id uuid primary key default gen_random_uuid(),
  room_code text unique not null,
  mode text not null check (mode in ('duel','duel_pari')),
  status text not null default 'waiting' check (status in ('waiting','bet_pending','playing','finished','abandoned','cancelled')),
  creator_id uuid not null references public.profiles(id),
  opponent_id uuid references public.profiles(id),
  current_turn_player_id uuid references public.profiles(id),
  winner_id uuid references public.profiles(id),
  stake_credits bigint not null default 0,
  bet_status text not null default 'none' check (bet_status in ('none','pending','accepted','rejected')),
  deck_state jsonb,
  discard_state jsonb,
  hands_state jsonb,
  rules_state jsonb,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.duel_game_actions (
  id bigserial primary key,
  game_id uuid not null references public.duel_games(id) on delete cascade,
  actor_id uuid not null references public.profiles(id),
  action_type text not null,
  action_payload jsonb not null default '{}'::jsonb,
  turn_number int,
  created_at timestamptz not null default now()
);

create table if not exists public.duel_chat_messages (
  id bigserial primary key,
  game_id uuid not null references public.duel_games(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  message text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.duel_presence (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  online boolean not null default false,
  last_seen timestamptz not null default now(),
  current_game_id uuid references public.duel_games(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.credit_transactions (
  id bigserial primary key,
  game_id uuid references public.duel_games(id),
  player_id uuid not null references public.profiles(id),
  amount bigint not null,
  reason text not null,
  idempotency_key text unique,
  created_at timestamptz not null default now()
);

create table if not exists public.game_history (
  id bigserial primary key,
  game_id uuid not null references public.duel_games(id) on delete cascade,
  player_id uuid not null references public.profiles(id),
  opponent_id uuid not null references public.profiles(id),
  result text not null check (result in ('win','loss')),
  mode text not null,
  stake_credits bigint not null default 0,
  credit_delta bigint not null default 0,
  created_at timestamptz not null default now()
);

create or replace view public.player_stats as
select
  p.id as player_id,
  p.wins,
  p.losses,
  p.games_played,
  p.credits_won,
  p.score
from public.profiles p
where p.games_played > 0;

create or replace view public.leaderboard as
select
  p.id as player_id,
  p.display_name,
  p.wins,
  p.losses,
  p.games_played,
  p.credits_won,
  p.score
from public.profiles p
where p.games_played > 0
order by p.score desc, p.wins desc;

alter table public.profiles enable row level security;
alter table public.duel_games enable row level security;
alter table public.duel_game_actions enable row level security;
alter table public.duel_chat_messages enable row level security;
alter table public.duel_presence enable row level security;
alter table public.credit_transactions enable row level security;
alter table public.game_history enable row level security;

create policy "profiles_read_all" on public.profiles for select using (true);
create policy "profiles_update_self" on public.profiles for update using (auth.uid() = id);
create policy "profiles_insert_self" on public.profiles for insert with check (auth.uid() = id);

create policy "games_read_participants" on public.duel_games
for select using (auth.uid() = creator_id or auth.uid() = opponent_id);
create policy "games_insert_creator" on public.duel_games
for insert with check (auth.uid() = creator_id);
create policy "games_update_participants" on public.duel_games
for update using (auth.uid() = creator_id or auth.uid() = opponent_id);

create policy "actions_read_participants" on public.duel_game_actions
for select using (
  exists(select 1 from public.duel_games g where g.id = game_id and (auth.uid() = g.creator_id or auth.uid() = g.opponent_id))
);
create policy "actions_insert_participants" on public.duel_game_actions
for insert with check (
  auth.uid() = actor_id and
  exists(select 1 from public.duel_games g where g.id = game_id and (auth.uid() = g.creator_id or auth.uid() = g.opponent_id))
);

create policy "chat_read_participants" on public.duel_chat_messages
for select using (
  exists(select 1 from public.duel_games g where g.id = game_id and (auth.uid() = g.creator_id or auth.uid() = g.opponent_id))
);
create policy "chat_insert_sender" on public.duel_chat_messages
for insert with check (
  auth.uid() = sender_id and
  exists(select 1 from public.duel_games g where g.id = game_id and (auth.uid() = g.creator_id or auth.uid() = g.opponent_id))
);

create policy "presence_read_authenticated" on public.duel_presence for select using (auth.role() = 'authenticated');
create policy "presence_upsert_self" on public.duel_presence for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "history_read_self" on public.game_history for select using (auth.uid() = player_id);
create policy "credits_read_self" on public.credit_transactions for select using (auth.uid() = player_id);

-- Sensitive credits logic via RPC
create or replace function public.apply_duel_bet_result(
  p_game_id uuid,
  p_winner_id uuid,
  p_loser_id uuid,
  p_stake bigint,
  p_idempotency_key text
) returns void
language plpgsql
security definer
as $$
begin
  if exists(select 1 from public.credit_transactions where idempotency_key = p_idempotency_key) then
    return;
  end if;

  update public.profiles
  set credits = credits - p_stake,
      losses = losses + 1,
      games_played = games_played + 1,
      score = score - 1,
      updated_at = now()
  where id = p_loser_id and credits >= p_stake;

  update public.profiles
  set credits = credits + p_stake,
      wins = wins + 1,
      games_played = games_played + 1,
      credits_won = credits_won + p_stake,
      score = score + 3,
      updated_at = now()
  where id = p_winner_id;

  insert into public.credit_transactions(game_id, player_id, amount, reason, idempotency_key)
  values
    (p_game_id, p_loser_id, -p_stake, 'duel_bet_loss', p_idempotency_key || ':L'),
    (p_game_id, p_winner_id, p_stake, 'duel_bet_win', p_idempotency_key || ':W');
end;
$$;
