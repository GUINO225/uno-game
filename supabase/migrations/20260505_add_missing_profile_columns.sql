-- Add missing columns used by lib/user_profile_service.dart
alter table public.profiles
  add column if not exists last_login_at timestamptz,
  add column if not exists profile_prompt_dismissed_at timestamptz;
