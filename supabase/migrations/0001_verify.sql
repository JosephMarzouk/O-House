-- =====================================================================
-- Post-migration verification for 0001_ohouse_app.sql
-- Run AFTER the migration. Raises on failure, prints 'ALL CHECKS PASSED'
-- on success. Rolls itself back — creates no permanent data.
-- =====================================================================

begin;

do $$
declare
  v_site uuid; v_user uuid; v_a1 uuid; v_a2 uuid; v_a3 uuid;
  v_status text; v_deadline timestamptz; v_n int; v_cairo_today date; v_was_extended bool;
begin
  select id into v_site from public.sites limit 1;
  select id into v_user from public.profiles limit 1;

  -- "Today" per the club's own clock, not the SQL session's timezone —
  -- current_date alone is ambiguous the moment the two disagree, which
  -- is exactly what broke the overnight check below.
  select (now() at time zone 'Africa/Cairo')::date into v_cairo_today;

  -- ---- expiry: same-day window already closed -----------------------
  insert into public.submissions
    (site_id, inspector_id, inspector_name, scheduled_date, window_start, window_end, status, submitted_at)
  values (v_site, v_user, 'test', v_cairo_today - 1, '06:00', '09:00', 'pending', null)
  returning id into v_a1;

  select effective_status into v_status from public.assignments_v where id = v_a1;
  if v_status <> 'expired' then
    raise exception 'FAIL: yesterday 06:00-09:00 should be expired, got %', v_status;
  end if;

  -- ---- expiry: future window is NOT expired --------------------------
  insert into public.submissions
    (site_id, inspector_id, inspector_name, scheduled_date, window_start, window_end, status, submitted_at)
  values (v_site, v_user, 'test', v_cairo_today + 1, '06:00', '09:00', 'pending', null)
  returning id into v_a2;

  select effective_status into v_status from public.assignments_v where id = v_a2;
  if v_status <> 'pending' then
    raise exception 'FAIL: tomorrow should be pending, got %', v_status;
  end if;

  -- ---- overnight window: 22:00-02:00 must roll to the NEXT day -------
  -- off-by-one here silently expires an entire night shift
  insert into public.submissions
    (site_id, inspector_id, inspector_name, scheduled_date, window_start, window_end, status, submitted_at)
  values (v_site, v_user, 'test', v_cairo_today, '22:00', '02:00', 'pending', null)
  returning id into v_a3;

  select deadline into v_deadline from public.assignments_v where id = v_a3;
  -- Read the deadline back in Cairo terms too — the instant is right
  -- either way, but "which calendar day" only means something once you
  -- say which timezone's calendar (Cairo's DST puts it at UTC+3 right
  -- now, so 02:00 Cairo can land on the *previous* UTC calendar date).
  if (v_deadline at time zone 'Africa/Cairo')::date <> v_cairo_today + 1 then
    raise exception 'FAIL: overnight window deadline should land tomorrow, got % (Cairo: %)',
      v_deadline, (v_deadline at time zone 'Africa/Cairo');
  end if;

  -- ---- a submitted row must never later read as expired ---------------
  update public.submissions set status = 'submitted' where id = v_a1;
  select effective_status into v_status from public.assignments_v where id = v_a1;
  if v_status <> 'submitted' then
    raise exception 'FAIL: submitted must stay submitted, got %', v_status;
  end if;

  -- ---- extension moves the deadline without erasing the miss ----------
  update public.submissions
     set status = 'pending', extended_until = now() + interval '2 hours'
   where id = v_a1;
  select effective_status, was_extended into v_status, v_was_extended
    from public.assignments_v where id = v_a1;
  if v_status = 'expired' then
    raise exception 'FAIL: extension should un-expire the task';
  end if;
  if (select window_end from public.submissions where id = v_a1) <> '09:00'::time then
    raise exception 'FAIL: extension must not touch the original window_end';
  end if;

  -- ---- the 4 legacy submissions were backfilled, not left pending -----
  select count(*) into v_n from public.submissions
   where submitted_at is not null and status = 'pending';
  if v_n > 0 then
    raise exception 'FAIL: % legacy submitted row(s) still marked pending', v_n;
  end if;

  -- ---- roles: 'cleaner' now allowed by BOTH constraint and RPC --------
  begin
    update public.profiles set role = 'cleaner' where id = v_user;
  exception when check_violation then
    raise exception 'FAIL: profiles_role_check still rejects cleaner';
  end;

  -- ---- new objects exist ---------------------------------------------
  if to_regclass('public.assignment_items') is null then
    raise exception 'FAIL: assignment_items missing';
  end if;
  if to_regclass('public.device_tokens') is null then
    raise exception 'FAIL: device_tokens missing';
  end if;
  if not exists (select 1 from pg_proc where proname = 'submit_assignment') then
    raise exception 'FAIL: submit_assignment missing';
  end if;

  -- ---- the dashboard's tables are untouched ---------------------------
  if to_regclass('public.template_claims') is null then
    raise exception 'FAIL: template_claims was dropped — dashboard RLS depends on it';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'submissions' and column_name = 'answers'
  ) then
    raise exception 'FAIL: submissions.answers was dropped — legacy data lost';
  end if;

  raise notice 'ALL CHECKS PASSED';
end $$;

rollback;   -- discard the test rows
