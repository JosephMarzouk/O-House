-- =====================================================================
-- O House — app support migration for the "Check List" project
-- Target: Supabase project ptonujazlljpkgpfrkpw
--
-- PURELY ADDITIVE. No table is renamed, no column is dropped, no row is
-- deleted. The existing admin dashboard keeps working unchanged after
-- this runs.
--
-- Deliberately NOT done here (each would break the live dashboard):
--   * submissions -> assignments rename   (cosmetic; do it later, together)
--   * drop column submissions.answers     (only copy of 4 real submissions)
--   * drop table template_claims          (its RLS policy is load-bearing)
--
-- Vocabulary note: `submissions` now holds tasks in every state, not just
-- submitted ones, and `inspector_id` means "the person assigned". Reusing
-- them beats a rename that 404s every dashboard query.
--
-- Safe to re-run: every statement is guarded.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 0. Backups, before any DDL
-- ---------------------------------------------------------------------
create table if not exists _backup_pre_ohouse_submissions as select * from public.submissions;
create table if not exists _backup_pre_ohouse_profiles    as select * from public.profiles;


-- ---------------------------------------------------------------------
-- 1. profiles — phone login, deactivation, forced reset, locale
-- ---------------------------------------------------------------------
alter table public.profiles
  add column if not exists phone                text,
  add column if not exists active               bool not null default true,
  add column if not exists must_change_password bool not null default true,
  add column if not exists locale               text not null default 'en';

-- partial unique: most profiles have no phone, and NULLs must not collide
create unique index if not exists profiles_phone_key
  on public.profiles (phone) where phone is not null;

alter table public.profiles drop constraint if exists profiles_locale_check;
alter table public.profiles add constraint profiles_locale_check
  check (locale in ('en','ar'));

-- widen roles; 'inspector' stays, the 5 existing profiles use it
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role = any (array['admin','manager','inspector','cleaner']));

comment on column public.profiles.phone is
  'E.164. App staff sign in with phone+password; dashboard admins keep using email.';

-- existing staff already know their passwords
update public.profiles set must_change_password = false;


-- ---------------------------------------------------------------------
-- 2. Two existing functions that would otherwise reject the new role
-- ---------------------------------------------------------------------

-- set_user_role() hardcodes the old 3-role list: without this, promoting
-- anyone to 'cleaner' fails even though the constraint above allows it.
create or replace function public.set_user_role(target_user_id uuid, new_role text)
returns void language plpgsql security definer set search_path to 'public' as $fn$
begin
  if public.current_role() <> 'admin' then
    raise exception 'Only admins can change user roles';
  end if;
  if new_role not in ('admin', 'manager', 'inspector', 'cleaner') then
    raise exception 'Invalid role: %', new_role;
  end if;
  update public.profiles set role = new_role where id = target_user_id;
end;
$fn$;

-- handle_new_user() has a latent bug that only bites phone-created users:
--   1. name came from split_part(email,'@') -> NULL when there is no email
--      (the explicit INSERT bypasses the column's '' default)
--   2. profiles.email is NOT NULL, so inserting a NULL email errors outright
-- Both matter the moment you create your first phone-only cleaner.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path to 'public' as $fn$
begin
  insert into public.profiles (id, name, email, role)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      new.phone,
      'Unnamed'
    ),
    coalesce(new.email, ''),          -- profiles.email is NOT NULL
    'cleaner'
  )
  on conflict (id) do nothing;
  return new;
end;
$fn$;


-- ---------------------------------------------------------------------
-- 3. submissions — task lifecycle, scheduling window, expiry, late sync
-- ---------------------------------------------------------------------
alter table public.submissions
  add column if not exists created_by         uuid references public.profiles(id),
  add column if not exists created_at         timestamptz not null default now(),
  add column if not exists title_en           text not null default '',
  add column if not exists title_ar           text not null default '',
  add column if not exists source_template_id uuid references public.templates(id),
  add column if not exists scheduled_date     date,
  add column if not exists window_start       time,
  add column if not exists window_end         time,
  add column if not exists status             text not null default 'pending',
  add column if not exists reviewed_by        uuid references public.profiles(id),
  add column if not exists reviewed_at        timestamptz,
  add column if not exists review_note        text,
  add column if not exists client_id          uuid,
  -- deadline extension (admin reopening an expired task)
  add column if not exists extended_until     timestamptz,
  add column if not exists extended_by        uuid references public.profiles(id),
  add column if not exists extended_at        timestamptz,
  add column if not exists extension_note     text,
  -- late-sync evidence
  add column if not exists completed_at       timestamptz,
  add column if not exists late_sync          bool not null default false;

-- a task exists long before it is submitted, so submitted_at must be nullable.
-- the default stays, so any existing dashboard INSERT keeps behaving as before.
alter table public.submissions alter column submitted_at drop not null;

-- the 4 pre-existing rows are genuinely submitted; without this they would
-- read as 'pending' and immediately show up as expired in the view below
update public.submissions set status = 'submitted'
  where submitted_at is not null and status = 'pending';

alter table public.submissions drop constraint if exists submissions_status_check;
alter table public.submissions add constraint submissions_status_check
  check (status in ('pending','in_progress','submitted','approved','rejected'));

-- offline idempotency: a retried submit after a timeout must not create a
-- second signed record. Partial, because existing rows have no client_id.
create unique index if not exists submissions_client_id_key
  on public.submissions (client_id) where client_id is not null;

create index if not exists submissions_assignee_date_idx
  on public.submissions (inspector_id, scheduled_date);

comment on column public.submissions.inspector_id is
  'The assigned staff member. Named inspector_id for dashboard compatibility.';
comment on column public.submissions.answers is
  'DEPRECATED. Live state now lives in assignment_items. Kept for the 4 legacy rows.';


-- ---------------------------------------------------------------------
-- 4. assignment_items — the checklist, promoted out of JSON
--    Column names mirror templates.items keys exactly, so creating a task
--    is a field-for-field copy with no translation layer to get wrong.
-- ---------------------------------------------------------------------
create table if not exists public.assignment_items (
  id               uuid primary key default gen_random_uuid(),
  assignment_id    uuid not null references public.submissions(id) on delete cascade,
  template_item_id text,                                  -- provenance only
  text_en          text not null default '',
  text_ar          text not null default '',
  type             text not null default 'yesno',
  critical         bool not null default false,
  requires_photo   bool not null default false,
  sort_order       int  not null default 0,
  status           text not null default 'pending'
                     check (status in ('pending','done','rejected')),
  done_at          timestamptz,
  note             text,
  reject_note      text,
  photo_paths      text[] not null default '{}'
);

create index if not exists assignment_items_assignment_idx
  on public.assignment_items (assignment_id, sort_order);

alter table public.assignment_items enable row level security;

-- SELECT only. Every write goes through a SECURITY DEFINER function below,
-- matching how set_action_status / set_user_role already work in this project.
drop policy if exists assignment_items_select on public.assignment_items;
create policy assignment_items_select on public.assignment_items for select using (
  exists (
    select 1 from public.submissions s
    where s.id = assignment_items.assignment_id
      and (
        s.inspector_id = auth.uid()
        or public.current_role() = 'admin'
        or (public.current_role() = 'manager'
            and s.inspector_id in (select id from public.profiles where manager_id = auth.uid()))
      )
  )
);


-- ---------------------------------------------------------------------
-- 5. device_tokens — push targets
-- ---------------------------------------------------------------------
create table if not exists public.device_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  fcm_token  text not null unique,
  platform   text not null check (platform in ('android','ios')),
  updated_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

drop policy if exists device_tokens_own on public.device_tokens;
create policy device_tokens_own on public.device_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());


-- ---------------------------------------------------------------------
-- 6. actions — make the dangling JSON reference a real foreign key
--    item_id text pointed into templates.items jsonb, which Postgres
--    cannot enforce: edit a template, drop an item, and every action
--    referencing it orphans silently. item_id is left populated.
-- ---------------------------------------------------------------------
alter table public.actions
  add column if not exists assignment_item_id uuid references public.assignment_items(id);


-- ---------------------------------------------------------------------
-- 7. assignments_v — expiry, derived not stored
--    Storing 'expired' would need a scheduled job and would be wrong for
--    however long that job is late. Reading the clock is always correct.
-- ---------------------------------------------------------------------
create or replace view public.assignments_v as
select
  a.*,
  coalesce(
    a.extended_until,
    ((a.scheduled_date + (case when a.window_end < a.window_start then 1 else 0 end))
      + a.window_end) at time zone 'Africa/Cairo'
  ) as deadline,
  case
    when a.status in ('submitted','approved','rejected') then a.status
    when a.scheduled_date is null or a.window_end is null then a.status
    when now() > coalesce(
      a.extended_until,
      ((a.scheduled_date + (case when a.window_end < a.window_start then 1 else 0 end))
        + a.window_end) at time zone 'Africa/Cairo'
    ) then 'expired'
    else a.status
  end as effective_status,
  (a.extended_until is not null) as was_extended
from public.submissions a;

comment on view public.assignments_v is
  'Read effective_status, never submissions.status. The +1 day handles overnight '
  'windows (22:00-02:00), matching template_window_open(). Africa/Cairo throughout.';


-- ---------------------------------------------------------------------
-- 8. RPCs. Every mutation is a function, matching this project's existing
--    style: no table here is opened up for direct client INSERT/UPDATE.
-- ---------------------------------------------------------------------

-- Admin creates a task. Takes the EDITED item array rather than a template
-- id, because the admin adjusts the checklist before assigning; the template
-- is provenance only.
create or replace function public.create_assignment(
  p_title_en           text,
  p_title_ar           text,
  p_site_id            uuid,
  p_assignee_id        uuid,
  p_scheduled_date     date,
  p_window_start       time,
  p_window_end         time,
  p_items              jsonb,
  p_source_template_id uuid default null,
  p_client_id          uuid default null
) returns uuid language plpgsql security definer set search_path to 'public' as $fn$
declare
  v_id uuid; v_site_ar text; v_site_en text; v_assignee_name text;
  v_item jsonb; v_i int := 0;
begin
  if public.current_role() not in ('admin','manager') then
    raise exception 'Only admins/managers can create assignments';
  end if;

  if p_client_id is not null then
    select id into v_id from public.submissions where client_id = p_client_id;
    if v_id is not null then return v_id; end if;      -- idempotent
  end if;

  select name_ar, name_en into v_site_ar, v_site_en
    from public.sites where id = p_site_id;

  select name into v_assignee_name from public.profiles where id = p_assignee_id;
  if v_assignee_name is null then raise exception 'Assignee not found'; end if;

  insert into public.submissions (
    template_id, template_title_ar, template_title_en,
    site_id, site_name_ar, site_name_en,
    inspector_id, inspector_name,
    title_en, title_ar, source_template_id,
    scheduled_date, window_start, window_end,
    status, created_by, client_id, submitted_at, answers
  ) values (
    p_source_template_id, p_title_ar, p_title_en,
    p_site_id, v_site_ar, v_site_en,
    p_assignee_id, v_assignee_name,
    p_title_en, p_title_ar, p_source_template_id,
    p_scheduled_date, p_window_start, p_window_end,
    'pending', auth.uid(), p_client_id, null, '[]'::jsonb
  ) returning id into v_id;

  for v_item in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
  loop
    insert into public.assignment_items (
      assignment_id, template_item_id, text_en, text_ar,
      type, critical, requires_photo, sort_order
    ) values (
      v_id,
      v_item ->> 'id',
      coalesce(v_item ->> 'text_en', ''),
      coalesce(v_item ->> 'text_ar', ''),
      coalesce(v_item ->> 'type', 'yesno'),
      coalesce((v_item ->> 'critical')::bool, false),
      coalesce((v_item ->> 'requires_photo')::bool, false),
      v_i
    );
    v_i := v_i + 1;
  end loop;

  return v_id;
end;
$fn$;


create or replace function public.mark_item_done(p_item_id uuid, p_note text default null)
returns void language plpgsql security definer set search_path to 'public' as $fn$
declare v_assignment uuid; v_assignee uuid; v_status text;
begin
  select i.assignment_id, s.inspector_id, s.status
    into v_assignment, v_assignee, v_status
  from public.assignment_items i
  join public.submissions s on s.id = i.assignment_id
  where i.id = p_item_id;

  if v_assignment is null then raise exception 'Item not found'; end if;
  if v_assignee is distinct from auth.uid() then raise exception 'Not authorized'; end if;
  if v_status in ('submitted','approved') then raise exception 'Assignment is closed'; end if;

  update public.assignment_items
     set status = 'done', done_at = now(),
         note = coalesce(p_note, note), reject_note = null
   where id = p_item_id;

  update public.submissions set status = 'in_progress'
   where id = v_assignment and status = 'pending';
end;
$fn$;


create or replace function public.attach_item_photo(p_item_id uuid, p_storage_path text)
returns void language plpgsql security definer set search_path to 'public' as $fn$
declare v_assignee uuid; v_status text;
begin
  select s.inspector_id, s.status into v_assignee, v_status
  from public.assignment_items i
  join public.submissions s on s.id = i.assignment_id
  where i.id = p_item_id;

  if v_assignee is null then raise exception 'Item not found'; end if;
  if v_assignee is distinct from auth.uid() then raise exception 'Not authorized'; end if;
  if v_status in ('submitted','approved') then raise exception 'Assignment is closed'; end if;

  update public.assignment_items
     set photo_paths = array_append(photo_paths, p_storage_path)
   where id = p_item_id
     and not (p_storage_path = any (photo_paths));   -- idempotent on replay
end;
$fn$;


-- The real trust boundary. The disabled Submit button is convenience only.
create or replace function public.submit_assignment(
  p_assignment_id uuid,
  p_signature_path text,
  p_completed_at timestamptz default null
) returns void language plpgsql security definer set search_path to 'public' as $fn$
declare
  v_assignee uuid; v_status text; v_deadline timestamptz;
  v_pending int; v_missing_photo int; v_late bool := false;
begin
  select a.inspector_id, a.status, v.deadline
    into v_assignee, v_status, v_deadline
  from public.submissions a
  join public.assignments_v v on v.id = a.id
  where a.id = p_assignment_id;

  if v_assignee is null then raise exception 'Assignment not found'; end if;
  if v_assignee is distinct from auth.uid() then raise exception 'Not authorized'; end if;
  if v_status in ('submitted','approved') then return; end if;   -- idempotent replay

  select count(*) into v_pending from public.assignment_items
   where assignment_id = p_assignment_id and status <> 'done';
  if v_pending > 0 then
    raise exception 'INCOMPLETE: % item(s) not done', v_pending;
  end if;

  select count(*) into v_missing_photo from public.assignment_items
   where assignment_id = p_assignment_id and requires_photo
     and coalesce(array_length(photo_paths, 1), 0) = 0;
  if v_missing_photo > 0 then
    raise exception 'MISSING_PHOTO: % item(s) require a photo', v_missing_photo;
  end if;

  -- Late sync: work finished inside the window but uploaded after it closed
  -- is accepted and FLAGGED, never discarded — losing a full round to a dead
  -- zone in the pool basement is the worse failure. p_completed_at comes from
  -- the device and is spoofable, which is exactly why it never passes silently.
  if v_deadline is not null then
    if p_completed_at is not null and p_completed_at <= v_deadline then
      v_late := now() > v_deadline;
    elsif now() > v_deadline then
      raise exception 'ASSIGNMENT_EXPIRED';
    end if;
  end if;

  update public.submissions
     set status        = 'submitted',
         submitted_at  = now(),
         completed_at  = coalesce(p_completed_at, now()),
         late_sync     = v_late,
         signature_url = p_signature_path
   where id = p_assignment_id;
end;
$fn$;


-- Admin extends a missed deadline. Additive: window_end is never touched, so
-- the original deadline stays recoverable and was_extended stays true forever.
create or replace function public.extend_assignment(
  p_assignment_id uuid, p_new_deadline timestamptz, p_note text default null
) returns void language plpgsql security definer set search_path to 'public' as $fn$
begin
  if public.current_role() not in ('admin','manager') then
    raise exception 'Only admins/managers can extend assignments';
  end if;
  if p_new_deadline <= now() then
    raise exception 'New deadline must be in the future';
  end if;

  update public.submissions
     set extended_until = p_new_deadline,
         extended_by    = auth.uid(),
         extended_at    = now(),
         extension_note = p_note
   where id = p_assignment_id
     and status not in ('submitted','approved');
end;
$fn$;


create or replace function public.reject_items(
  p_assignment_id uuid, p_item_ids uuid[], p_reason text
) returns void language plpgsql security definer set search_path to 'public' as $fn$
begin
  if public.current_role() not in ('admin','manager') then
    raise exception 'Only admins/managers can reject items';
  end if;

  update public.assignment_items
     set status = 'rejected', reject_note = p_reason, done_at = null
   where assignment_id = p_assignment_id and id = any(p_item_ids);

  update public.submissions
     set status = 'in_progress', review_note = p_reason,
         reviewed_by = auth.uid(), reviewed_at = now()
   where id = p_assignment_id;
end;
$fn$;


create or replace function public.approve_assignment(
  p_assignment_id uuid, p_score int default null
) returns void language plpgsql security definer set search_path to 'public' as $fn$
begin
  if public.current_role() not in ('admin','manager') then
    raise exception 'Only admins/managers can approve assignments';
  end if;

  update public.submissions
     set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now(),
         score = coalesce(p_score, score)
   where id = p_assignment_id and status = 'submitted';
end;
$fn$;


-- ---------------------------------------------------------------------
-- 9. Lock the new functions to signed-in users.
--    The linter already flags this project's existing SECURITY DEFINER
--    functions as anon-executable; don't add seven more to that list.
-- ---------------------------------------------------------------------
revoke execute on function public.create_assignment(text,text,uuid,uuid,date,time,time,jsonb,uuid,uuid) from anon;
revoke execute on function public.mark_item_done(uuid,text)                  from anon;
revoke execute on function public.attach_item_photo(uuid,text)               from anon;
revoke execute on function public.submit_assignment(uuid,text,timestamptz)   from anon;
revoke execute on function public.extend_assignment(uuid,timestamptz,text)   from anon;
revoke execute on function public.reject_items(uuid,uuid[],text)             from anon;
revoke execute on function public.approve_assignment(uuid,int)               from anon;

commit;

-- =====================================================================
-- Rollback: everything above is additive, so undoing it is dropping the
-- new objects. The two _backup_pre_ohouse_* tables restore profiles and
-- submissions to their exact pre-migration state if anything is wrong.
-- =====================================================================
