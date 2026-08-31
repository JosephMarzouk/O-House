-- =====================================================================
-- Optional follow-up: scope uploads into checklist-media by ownership.
--
-- Today (verified live): one bucket exists, `checklist-media` (public),
-- with exactly two policies:
--   checklist_media_upload  INSERT  with_check: bucket_id = 'checklist-media'
--   checklist_media_read    SELECT  qual:       bucket_id = 'checklist-media'
-- Any authenticated caller can upload or read ANY object in the bucket —
-- there is no path-based ownership check. Fine for a small in-house team
-- where everyone is trusted staff; worth tightening before this app has
-- any outside reach. NOT applied — draft only, review before running.
--
-- Assumes the app writes photos to  photos/{assignment_id}/...
-- and signatures to                 signatures/{assignment_id}-...
-- (see lib/data/sync.dart). Read access is left as-is — every signed-in
-- staff member already sees every submission via existing table RLS
-- (manager hierarchy included), so a matching read restriction here
-- would just duplicate that without changing what anyone can reach.
-- =====================================================================

begin;

drop policy if exists checklist_media_upload on storage.objects;

create policy checklist_media_upload on storage.objects for insert with check (
  bucket_id = 'checklist-media'
  and (
    public.current_role() in ('admin', 'manager')
    or exists (
      select 1 from public.submissions s
      where s.inspector_id = auth.uid()
        and (
          name like 'photos/' || s.id || '/%'
          or name like 'signatures/' || s.id || '-%'
        )
    )
  )
);

commit;
