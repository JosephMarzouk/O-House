-- =====================================================================
-- profiles has no direct client UPDATE grant, by design (see 0001's
-- "no table here is opened up for direct client INSERT/UPDATE"). The
-- language toggle in profile_screen.dart called .from('profiles').update()
-- directly and hit 42501 permission denied. This adds the missing
-- SECURITY DEFINER RPC, matching mark_item_done/attach_item_photo: scoped
-- to auth.uid(), never a client-supplied id.
-- =====================================================================

begin;

create or replace function public.set_locale(p_locale text)
returns void language plpgsql security definer set search_path to 'public' as $fn$
begin
  if p_locale not in ('en','ar') then
    raise exception 'Invalid locale: %', p_locale;
  end if;
  update public.profiles set locale = p_locale where id = auth.uid();
end;
$fn$;

revoke execute on function public.set_locale(text) from anon;

commit;
