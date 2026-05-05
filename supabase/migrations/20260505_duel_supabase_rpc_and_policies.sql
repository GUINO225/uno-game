-- Ensure profile columns required by app logic exist
alter table public.profiles
  add column if not exists display_name text,
  add column if not exists photo_url text,
  add column if not exists credits integer not null default 1000,
  add column if not exists wins integer not null default 0,
  add column if not exists losses integer not null default 0,
  add column if not exists games_played integer not null default 0,
  add column if not exists updated_at timestamptz not null default now();

-- Strict self read/update policy requested for profile updates
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

-- Chat table used by duel_mode realtime chat
create table if not exists public.duel_chat_messages (
  id uuid primary key default gen_random_uuid(),
  game_id text not null references public.duel_games(room_code) on delete cascade,
  sender_id uuid not null,
  sender_name text not null,
  text text not null,
  created_at timestamptz not null default now()
);

alter table public.duel_chat_messages enable row level security;

drop policy if exists "chat_read_participants_room_code" on public.duel_chat_messages;
create policy "chat_read_participants_room_code" on public.duel_chat_messages
for select to authenticated
using (
  exists (
    select 1
    from public.duel_games g
    where g.room_code = duel_chat_messages.game_id
      and (auth.uid() = g.creator_id or auth.uid() = g.opponent_id)
  )
);

drop policy if exists "chat_insert_participants_room_code" on public.duel_chat_messages;
create policy "chat_insert_participants_room_code" on public.duel_chat_messages
for insert to authenticated
with check (
  auth.uid() = sender_id
  and exists (
    select 1
    from public.duel_games g
    where g.room_code = duel_chat_messages.game_id
      and (auth.uid() = g.creator_id or auth.uid() = g.opponent_id)
  )
);

-- Transactional stake RPCs
create or replace function public.propose_duel_stake(
  p_room_code text,
  p_proposed_by uuid,
  p_amount integer
) returns void
language plpgsql
security definer
as $$
begin
  update public.duel_games g
  set
    stake_amount = greatest(p_amount, 0),
    stake_proposed_by = p_proposed_by,
    stake_accepted_by = null,
    stake_status = 'pending',
    bet_flow_state = 'initialStakePendingResponse',
    active_stake_credits = 0,
    updated_at = now()
  where g.room_code = p_room_code
    and (auth.uid() = g.creator_id or auth.uid() = g.opponent_id);

  if not found then
    raise exception 'Room not found or unauthorized';
  end if;
end;
$$;

create or replace function public.accept_duel_stake(
  p_room_code text,
  p_responder_id uuid
) returns void
language plpgsql
security definer
as $$
declare
  v_amount integer;
begin
  select coalesce(stake_amount, 0)
  into v_amount
  from public.duel_games g
  where g.room_code = p_room_code
    and (auth.uid() = g.creator_id or auth.uid() = g.opponent_id)
  for update;

  if not found then
    raise exception 'Room not found or unauthorized';
  end if;

  update public.duel_games
  set
    stake_accepted_by = p_responder_id,
    stake_status = 'accepted',
    bet_flow_state = 'readyToStart',
    active_stake_credits = v_amount,
    status = 'playing',
    updated_at = now()
  where room_code = p_room_code;
end;
$$;

create or replace function public.reject_duel_stake(
  p_room_code text,
  p_responder_id uuid,
  p_insufficient_funds boolean default false
) returns void
language plpgsql
security definer
as $$
begin
  update public.duel_games g
  set
    stake_accepted_by = p_responder_id,
    stake_status = case when p_insufficient_funds then 'insufficientFunds' else 'declined' end,
    bet_flow_state = case when p_insufficient_funds then 'awaitingFundsValidation' else 'initialStakeRejected' end,
    active_stake_credits = 0,
    updated_at = now()
  where g.room_code = p_room_code
    and (auth.uid() = g.creator_id or auth.uid() = g.opponent_id);

  if not found then
    raise exception 'Room not found or unauthorized';
  end if;
end;
$$;

create or replace function public.resolve_duel_stake(
  p_room_code text,
  p_winner_id uuid
) returns void
language plpgsql
security definer
as $$
begin
  update public.duel_games g
  set
    winner_id = p_winner_id,
    stake_status = 'resolved',
    bet_flow_state = 'matchFinished',
    active_stake_credits = 0,
    status = 'finished',
    updated_at = now()
  where g.room_code = p_room_code
    and (auth.uid() = g.creator_id or auth.uid() = g.opponent_id);

  if not found then
    raise exception 'Room not found or unauthorized';
  end if;
end;
$$;

grant execute on function public.propose_duel_stake(text, uuid, integer) to authenticated;
grant execute on function public.accept_duel_stake(text, uuid) to authenticated;
grant execute on function public.reject_duel_stake(text, uuid, boolean) to authenticated;
grant execute on function public.resolve_duel_stake(text, uuid) to authenticated;
