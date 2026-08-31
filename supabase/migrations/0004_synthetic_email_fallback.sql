-- =====================================================================
-- Companion to the app-side fallback in lib/supabase.dart
-- (phoneToSyntheticEmail): this project's Phone provider isn't enabled,
-- so accounts are created via the dashboard's Email/Password form using
-- a disguised address like 201234567890@ohouse.internal instead.
--
-- 0003 copied new.phone into profiles.phone — but an account created
-- this way has new.phone = null (nothing was ever typed into a phone
-- field), so 0003 alone leaves profiles.phone empty again for exactly
-- the accounts you're about to create. This recognizes the disguise and
-- extracts the real number back out of it. Real phone-created accounts
-- (if the provider gets enabled later) keep working exactly as before —
-- this only changes behavior for @ohouse.internal addresses.
-- =====================================================================

begin;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path to 'public' as $fn$
declare
  v_synthetic bool := new.email like '%@ohouse.internal';
  v_phone text := coalesce(
    new.phone,
    case when new.email like '%@ohouse.internal'
      then '+' || split_part(new.email, '@', 1)
      else null
    end
  );
begin
  insert into public.profiles (id, name, email, phone, role)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      v_phone,
      'Unnamed'
    ),
    case when v_synthetic then '' else coalesce(new.email, '') end,  -- never store the disguise
    v_phone,
    'cleaner'
  )
  on conflict (id) do nothing;
  return new;
end;
$fn$;

commit;
