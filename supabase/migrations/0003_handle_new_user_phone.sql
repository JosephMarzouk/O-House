-- =====================================================================
-- Small follow-up to 0001: handle_new_user() never copied phone into
-- profiles.phone (only id/name/email/role were inserted). Login itself
-- is unaffected — signInWithPassword matches against auth.users.phone,
-- not profiles.phone — but the profile row would silently show no phone
-- number for every account created from here on, including the test
-- account you're about to make. One-line fix, applied once.
-- =====================================================================

begin;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path to 'public' as $fn$
begin
  insert into public.profiles (id, name, email, phone, role)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      new.phone,
      'Unnamed'
    ),
    coalesce(new.email, ''),          -- profiles.email is NOT NULL
    new.phone,                        -- profiles.phone IS nullable — fine as-is
    'cleaner'
  )
  on conflict (id) do nothing;
  return new;
end;
$fn$;

commit;
