alter table if exists public.duel_games
  add column if not exists game_state jsonb not null default '{}'::jsonb,
  add column if not exists last_action jsonb,
  add column if not exists last_action_by text,
  add column if not exists current_turn text,
  add column if not exists revision integer not null default 0,
  add column if not exists updated_at timestamptz not null default now();
