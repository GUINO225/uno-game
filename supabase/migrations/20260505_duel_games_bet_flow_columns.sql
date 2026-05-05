-- Ensure duel/paris flow columns exist in public.duel_games
alter table public.duel_games
  add column if not exists bet_flow_state text,
  add column if not exists stake_status text,
  add column if not exists stake_amount integer default 0,
  add column if not exists stake_proposed_by text,
  add column if not exists stake_accepted_by text,
  add column if not exists active_stake_credits integer default 0;

alter table public.duel_games
  alter column active_stake_credits set default 0,
  alter column stake_amount set default 0;
