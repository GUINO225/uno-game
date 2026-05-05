-- STEP 1: Normalize duel_games mode/status/stake contract

-- 1) Normalize mode values
update public.duel_games set mode = 'duel_pari' where mode in ('credits', 'pari');
update public.duel_games set mode = 'duel' where mode in ('simple', 'duel_simple');

-- 2) Normalize status values
update public.duel_games set status = 'betting' where status in ('bet_pending');
update public.duel_games set status = 'round' where status in ('playing');
update public.duel_games set status = 'finished' where status in ('abandoned', 'cancelled');

-- 3) Ensure stake_status exists and is populated from bet_status when needed
alter table public.duel_games
  add column if not exists stake_status text;

update public.duel_games
set stake_status = case
  when coalesce(stake_status, '') <> '' then stake_status
  when bet_status = 'pending' then 'pending'
  when bet_status = 'accepted' then 'accepted'
  when bet_status = 'declined' then 'declined'
  when bet_status = 'rejected' then 'declined'
  when bet_status = 'resolved' then 'resolved'
  else 'none'
end;

-- 4) Rebuild constraints with normalized value sets
alter table public.duel_games drop constraint if exists duel_games_mode_check;
alter table public.duel_games
  add constraint duel_games_mode_check check (mode in ('duel', 'duel_pari'));

alter table public.duel_games drop constraint if exists duel_games_status_check;
alter table public.duel_games
  add constraint duel_games_status_check check (status in ('waiting', 'betting', 'round', 'finished'));

alter table public.duel_games drop constraint if exists duel_games_stake_status_check;
alter table public.duel_games
  add constraint duel_games_stake_status_check check (stake_status in ('none', 'pending', 'accepted', 'declined', 'resolved', 'insufficientFunds'));

alter table public.duel_games
  alter column stake_status set default 'none';

-- 5) Remove legacy bet_status column (after migration)
alter table public.duel_games drop column if exists bet_status;
