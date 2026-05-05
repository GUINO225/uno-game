ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS last_login_at timestamptz;

ALTER TABLE public.duel_games
ADD COLUMN IF NOT EXISTS bet_status text DEFAULT 'idle';

ALTER TABLE public.duel_games
ADD COLUMN IF NOT EXISTS bet_flow_state text;

ALTER TABLE public.duel_games
ADD COLUMN IF NOT EXISTS stake_amount integer DEFAULT 0;

ALTER TABLE public.duel_games
ADD COLUMN IF NOT EXISTS stake_proposed_by uuid;

ALTER TABLE public.duel_games
ADD COLUMN IF NOT EXISTS stake_accepted_by uuid;

ALTER TABLE public.duel_games
ADD COLUMN IF NOT EXISTS active_stake_credits integer DEFAULT 0;
