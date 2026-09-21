-- =====================================================================
-- submit_assignment() accepts a partial round.
--
-- 0001 raised INCOMPLETE on any item not 'done', but the app's own gate
-- (canSubmitStaged, lib/features/assignments/detail_screen.dart) has always
-- allowed submitting what was actually finished — "I did what I could" is
-- the real shape of a cleaning round that ran out of window. The two
-- disagreed, and because submits drain through the outbox the rejection
-- never reached the user: they saw the success screen and the row retried
-- forever.
--
-- The trust boundary does not go away, it moves: a submission must still
-- carry work (EMPTY_SUBMISSION) and every place claimed done must still
-- carry its evidence (MISSING_PHOTO). Only "every place must be done" is
-- dropped.
--
-- Everything else — the auth check, the idempotent replay, the late-sync
-- and expiry rules, the final update — is 0001's, unchanged.
--
-- One behaviour change worth knowing: an assignment with *zero* items used
-- to submit cleanly (nothing pending, no photos owed) and now raises
-- EMPTY_SUBMISSION. That matches Assignment.canSubmit, which already
-- requires items.isNotEmpty. Every all-items-done submit keeps working, so
-- the admin dashboard is unaffected.
-- =====================================================================

begin;

create or replace function public.submit_assignment(
  p_assignment_id uuid,
  p_signature_path text,
  p_completed_at timestamptz default null
) returns void language plpgsql security definer set search_path to 'public' as $fn$
declare
  v_assignee uuid; v_status text; v_deadline timestamptz;
  v_done int; v_missing_photo int; v_late bool := false;
begin
  select a.inspector_id, a.status, v.deadline
    into v_assignee, v_status, v_deadline
  from public.submissions a
  join public.assignments_v v on v.id = a.id
  where a.id = p_assignment_id;

  if v_assignee is null then raise exception 'Assignment not found'; end if;
  if v_assignee is distinct from auth.uid() then raise exception 'Not authorized'; end if;
  if v_status in ('submitted','approved') then return; end if;   -- idempotent replay

  -- A submission has to carry work. Mirrors canSubmitStaged's anyChecked;
  -- a signed round with nothing done is not a partial submit, it is noise.
  select count(*) into v_done from public.assignment_items
   where assignment_id = p_assignment_id and status = 'done';
  if v_done = 0 then
    raise exception 'EMPTY_SUBMISSION: no item(s) done';
  end if;

  -- Only places actually claimed done owe evidence. An untouched place that
  -- requires a photo is simply not part of this submission — it stays
  -- pending for whoever picks the round up next.
  select count(*) into v_missing_photo from public.assignment_items
   where assignment_id = p_assignment_id and requires_photo
     and status = 'done'
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

-- create or replace keeps the existing ACL, but 0001 revoked this explicitly
-- and saying so again costs nothing.
revoke execute on function public.submit_assignment(uuid,text,timestamptz) from anon;

commit;
