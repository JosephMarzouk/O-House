# o_house — project map & handoff

Flutter staff app for the **O House** club (Cairo). Cleaners/inspectors get
assigned checklist rounds, tick places off, attach camera evidence, sign, and
submit. Backend is Supabase (project `ptonujazlljpkgpfrkpw`, "Check List"),
shared with an existing admin web dashboard that must keep working.

Bilingual EN/AR with full RTL. Phone-portrait only. Designed for gloved hands
(44px min tap targets, 56px primaries).

---

## 1. Run it

```bash
flutter pub get
```

Each club is its own app (a flavor, see "Clubs" below), so every run and
build names one. Dev talks to the API on this computer over USB, so run
`adb reverse tcp:4000 tcp:4000` once per phone connection (emulator too).
`tool/run_dev.ps1` does both, so the reverse can't be forgotten (30 Sep: a
phone without it sat offline for a day and nothing said so; the sync banner
now does, and in dev it names `127.0.0.1:4000`).

```bash
flutter run                      # or: powershell -ExecutionPolicy Bypass -File tool\run_dev.ps1
```

That is O House in dev (the default flavor and `ENVIRONMENT`); in full,
`flutter run --flavor owest --dart-define=TENANT_NAME=OWEST --dart-define=ENVIRONMENT=dev`.

```bash
flutter build appbundle --flavor owest --dart-define=TENANT_NAME=OWEST --dart-define=ENVIRONMENT=prod
```

`pubspec.yaml` sets `default-flavor: owest`, so the IDE's Run button and a
bare `flutter run` build O House (without it, Flutter installed a stale
pre-flavor `build/…/app-debug.apk`, club-code screen and all). Other clubs
pass `--flavor <club>`. `ENVIRONMENT` defaults to `dev`; `ENVIRONMENT=prod`
needs `--dart-define=API_URL=...` until the API is deployed.

| Task | Command |
|---|---|
| Tests | `flutter test` |
| Analyze | `flutter analyze` (clean as of last check) |
| Regenerate l10n | `flutter gen-l10n` (config in `l10n.yaml`) |
| Screen preview, no login | `flutter run -t lib/main_dev_preview.dart` |

**Browser preview** (visual verification; web builds take no `--flavor`, so
the app itself refuses to start there, and only `main_dev_preview.dart`
renders): `flutter run -d web-server` renders a
black canvas for this project. What works is `flutter build web --release`
(~4 min) then serving `build/web` over a static HTTP server. Note `sqflite` has
no web implementation, so anything touching `LocalDb` silently no-ops there.

`main_dev_preview.dart` is a throwaway entrypoint that mounts one screen with
fake data: `?screen=home|tasks|profile`, `?lang=ar`.

---

## 2. Current state — READ THIS FIRST

**`main` is the current build** (27 Sep: `rounds-follow-up-tracker`, which
carried every screen, the answers / follow-up / zone-round work, Step 3, the
tenant method, About / Policies and the default flavor, was fast-forwarded
into it). Work on `main` or branch from it.

Refactored away in `8f4202a`, do not resurrect:
`lib/features/assignments/item_sheet.dart` → folded into `subtask_tile.dart`;
`lib/features/auth/custom_widgets/LanguageToggle.dart` → `lib/widgets/language_toggle.dart`;
`lib/main_dev_home_preview.dart` → `lib/main_dev_preview.dart`;
`.claude/launch.json`.

### Phase status

| Phase | Scope | State |
|---|---|---|
| 1 | Online-only reads/writes, all screens | **Done** |
| 2 | Image compression before queuing | **Done (Step 3)** — the picker itself: 1600 px long edge, quality 75 |
| 3 | Offline writes: outbox drain, optimistic local updates, cache reads | **Code done (plan Step 3)** — every read and write goes through the O House API (`data/api_client.dart`); cache-first providers; SyncService v2 (per-round order, backoff, parking with Retry/Dismiss, user-scoped); one app per club (tenant flavors). Verified on a real phone against the local API: reads, and an offline submit (Wi-Fi off) that sent itself on reconnect, signature in storage, `completed_at` = signing time |
| 4 | Push notifications | **Done for Android (12 Oct), checked on a real phone** — `lib/push/push_service.dart`. Firebase from the flavor's `android/app/src/<flavor>/google-services.json` (only `owest` has one: project `o-house-4fce4`; RYZE and KODE build with push off). The token goes to `PUT /me/devices` while signed in and is removed at sign-out (`DELETE`, then `deleteToken`). Home asks for permission once, with a one-line reason, only while Android hasn't decided. A push in the foreground shows a banner (Open) and refreshes the rounds; a tap opens `data.open`: the round, Tasks, or Home. `MainActivity` makes the `rounds` channel. The server writes the text (EN/AR). E10 (upload refused) not built yet |
| — | Club zone (29–30 Sep) | **Done, checked on a real phone** — a checklist that can still be filled opens and submits only inside the club's zone (`club_location`, a point and a radius set once on the portal; it rides on `GET /me` as `location`). The check is in the app only (`geolocator`). Home asks for location as soon as the club has a zone; a refusal, location off, approximate-only, a mocked position or "N m from the club" replace the checklist with a message and Retry / Open settings. **Fails closed:** until `/me` has succeeded once on this phone (`club_location_synced`), checklists stay shut ("Connect to the internet once…"). No zone set = no gate |
| — | Sync you can see (30 Sep) | Resume and reconnect refetch `/assignments` and `/me` (30 s throttle; at once after a failure); pull to refresh fetches `/me` too. A failed fetch shows "Can't reach the server — showing saved tasks · Last updated HH:mm" whatever the outbox holds. An overnight window (22:00 → 01:00) stays in Today until its deadline |
| — | Role names (29 Sep) | The header shows the role's own name from `/me`'s `access.role` (custom roles included), in the reader's language, cached with the profile. The app still gates nothing by role |

### Known issues

Step 3 (plan) fixed 1, 2, 6, 7 and 8 below: kept for the history, not open.
Still open: **4** (the app id is an open product decision) and **5**.

1. **Offline reads are broken, and the cache is write-only.**
   `myAssignmentsProvider` always calls `refreshFromServer`;
   `AssignmentsRepo.myAssignments()` (the cache read) is only reachable when
   `kDemoData` is true. Offline the provider errors and every screen renders
   `valueOrNull ?? []` — "you have no tasks" — and a deep-linked task detail
   spins forever. A fix must also solve two things: `currentProfileProvider` is
   itself a network `select()` awaited first, and `myAssignments()` has no
   assignee filter, so a naive cache read leaks one staff member's rounds to
   the next on a shared device.
2. **Retrying Submit duplicates photo evidence.** *(Unchanged by the
   answers/follow-up work.)* `detail_screen._submit` re-enables itself when
   the signature route pops and never clears `_newPhotos`/`_answers`. Back out
   of signing, tap Submit again, and the same file is enqueued twice under two
   `microsecondsSinceEpoch` paths — defeating `attach_item_photo`'s
   `not (p_storage_path = any(photo_paths))` guard. There is deliberately no
   way to delete a photo, so it is permanent. (The answers are re-queued too,
   but harmlessly: the same answer twice lands the same verdict, and
   `flagged_answer` keeps only the first miss.)
3. **Storage bucket is unscoped.** `checklist-media` is public with
   bucket-id-only RLS — any signed-in user can read/write any object.
   `supabase/migrations/0002_storage_scoping.sql` is the drafted fix, **not
   applied**.
4. `android/app/build.gradle.kts` still has `applicationId = "com.example.o_house"`.
5. Dial code `+20` is assumed, not confirmed with the club
   (`login_screen.dart:17`).
6. A terminal sync rejection is dropped silently for anyone **not** standing on
   the signature screen (which reads `SyncService.lastError` and refuses to
   show the success screen). A round rejected during a background drain still
   vanishes with no notification. `TODO(phase-4)` in `sync.dart`.
7. **`INTERNET` is granted only by accident.**
   `android/app/src/main/AndroidManifest.xml` declares no permissions; the
   merged release manifest gets `INTERNET` from `firebase_messaging`'s own
   manifest. Drop that unused dependency and release builds silently lose
   network while debug keeps working. Declare it explicitly.
8. **iOS has no `NSCameraUsageDescription`** in `ios/Runner/Info.plist` while
   `detail_screen.dart` calls `ImagePicker(source: camera)`. The OS kills the
   app on the first photo. Ship blocker on iOS. Video recording also needs
   `NSMicrophoneUsageDescription`.

---

## 3. Architecture

```
main.dart → authService.load() → ProviderScope → OHouseApp (app.dart)
                                                  ↓
                                       MaterialApp.router + buildTheme()
                                                  ↓
                                            router.dart (go_router)
```

- **State**: Riverpod. All providers live in `lib/data/providers.dart`.
- **Since Step 3 the app never reaches the database or Storage.** Every read
  and write is HTTPS to the O House API (`data/api_client.dart`, `X-Club` on
  every call).
- **Sign-in is the API's too (since 27 Sep); the app has no Supabase at all.**
  `data/auth_service.dart` (`authService`, a `ChangeNotifier`) calls
  `POST /auth/login` / `refresh` / `logout` and keeps the two tokens in
  `flutter_secure_storage`. Parallel refreshes share one call; a network
  failure never signs anyone out (the refresh token lasts 30 days, the outbox
  waits). The router listens to it (`refreshListenable`).
- **Several assignees.** A round can be assigned to several people; it shows up
  for all of them until the first one acts (answer, photo or submit) and claims
  it. After that the others' refresh drops it, and an offline write from them
  is parked with "Already taken by …" (`ASSIGNMENT_TAKEN`). A round can also
  run over several days (`endDate`): it stays in Today until its end date.
- **Evidence is photos or camera video** (30 s max, MP4), never the gallery.
- **The one seam**: `AssignmentsRepo`. No screen touches the API directly
  (Profile's locale is the exception).
- **No password screen.** Staff never change their password in the app
  (business rule): only an admin sets it, in the portal. Sign-in always lands
  on Home; `profiles.must_change_password` is not read.
- **Push** (`lib/push/push_service.dart`): `initPush()` in `main.dart` starts
  Firebase (off when the flavor has no `google-services.json`, in tests and on
  web: `pushAvailable`) and keeps a tap that launched the app in
  `pendingPushRoute`, which Splash and Login open over Home after their own
  checks. `pushServiceProvider` (kept alive in `app.dart`) holds the token and
  the foreground handlers while someone is signed in; `unregisterPush` runs in
  Profile's sign-out before the session goes. The banner uses the
  `scaffoldMessengerKey` on `MaterialApp.router`.
- **About / Policies** come from `club_pages` (an admin writes them in the
  portal), on `GET /me` as `pages`, cached in `settings` (`clubPagesProvider`)
  so they show offline; empty → the built-in ARB line.
- **Cache first** (LS-3): `myAssignmentsProvider` reads the per-user cache and
  lays queued work over it (`applyLocal`); `roundsRefreshProvider` does the
  `GET /assignments`. One SQLite file (`o_house.db`, schema v2; v1 is the
  pre-Step-3 file and is upgraded in place, old unsent rows kept aside in
  `legacy_outbox`); every row carries its user.
- **Offline shape**: writes are enqueued (`answer` / `photo` / `submit`, ids
  fixed at capture, evidence in `documents/evidence/`). `SyncService`
  sends them per round in order; a 422 `refused` parks the op (banner → Retry /
  Dismiss), everything else retries with backoff. See `data/sync.dart`.

### Routes (`lib/router.dart`)

| Path | Screen | Notes |
|---|---|---|
| `/splash` | `SplashScreen` | Cold boot only. Owns the routing decision. |
| `/login` | `LoginScreen` | `NoTransitionPage` — owns its own ink animation |
| `/home` `/tasks` `/profile` | `StatefulShellRoute.indexedStack` | Three peer tabs, state preserved, floating `AppNavBar` |
| `/tasks/:id` | `TaskDetailScreen` | Top-level on purpose — no nav bar, keeps back arrow |
| `/tasks/:id/signature` | `SignatureScreen` | |
| `/tasks/:id/success` | `SuccessScreen` | |
| `/history/:id` | `HistoryDetailScreen` | Read-only submitted round |

The redirect guard skips `/splash` and `/login` (each owns its own routing);
everything else bounces to `/login` without a session.

### The splash hand-off animation

A deliberate, load-bearing piece of design. The splash's full-screen ink block
does not cut — it *shrinks* into the next screen's header.

- `lib/features/splash_handoff.dart` — the `SplashHandoffAnimation` mixin
  decides where the ink starts and how long it takes. Three cases: first screen
  after splash (full screen, 1300ms), Home arriving from Login (starts at
  Login's header height, 620ms), any later visit (no animation). One-shot per
  app process via `splashHandoffPlayed`.
- `lib/widgets/ink_handoff_panel.dart` — the shared shrinking-panel chrome.
- Login shows a static `BrandPanel`; Home animates logo (glides + resizes) and
  text (crossfades) separately via `HomeHeaderOverlay`.
- This is why `/login` and `/home` use `NoTransitionPage` and why the shell
  sets `extendBody: true`. Don't "clean up" either.

---

## 4. File map

### Entry & shell

| File | Purpose |
|---|---|
| `lib/main.dart` | Boot: portrait lock, `authService.load()` (tokens from secure storage), `ProviderScope` |
| `lib/push/push_service.dart` | Push: `initPush`, `pushServiceProvider` (token, foreground banner, taps), `routeFor`, `askPushPermission` (Home), `unregisterPush` (sign-out) |
| `lib/tenant.dart` | **Clubs.** `enum Tenant`, `TenantConfig` (API slug, names, brand colours, logo; no Supabase URL or key), tenant from `appFlavor` checked against `TENANT_NAME`, `apiBaseUrl` from `ENVIRONMENT` |
| `lib/app.dart` | `MaterialApp.router`, theme, locale, l10n delegates |
| `lib/router.dart` | All routes + auth redirect (`refreshListenable: authService`) |
| `lib/theme.dart` | `AppColors`, radii, shadows, `buildTheme()` |
| `lib/main_dev_preview.dart` | Throwaway screen-preview entrypoint |

### Data

| File | Purpose |
|---|---|
| `lib/data/providers.dart` | Every Riverpod provider |
| `lib/data/auth_service.dart` | `AuthService`: sign-in (phone or email), shared refresh, sign-out, tokens in secure storage; `normalizePhone` |
| `lib/data/assignments_repo.dart` | **The seam.** Reads/refresh/writes + demo-mode branch. Refresh fetches the last 7 days plus anything in `follow_up`, items in chunks of 50 rounds |
| `lib/data/api_client.dart` | The only way to the data: `X-Club`, bearer, `Idempotency-Key`, one 401 refresh, the refusal contract (`ApiRefused` / `ApiUnavailable`) |
| `lib/data/local_db.dart` | sqflite v2: `rounds`, `profiles`, `outbox`, `drafts`, `settings`, all keyed by user |
| `lib/data/sync.dart` | SyncService v2: per-round order, backoff, parking (Retry / Dismiss), rerun flag, `SyncStatus` for the banner |
| `lib/data/fixtures.dart` | Demo data for tests and `main_dev_preview.dart` (injected through provider overrides; the app never reads it) |

Providers: `localDbProvider`, `assignmentsRepoProvider`, `syncServiceProvider`,
`outboxCountProvider`, `authStateProvider`, `currentProfileProvider`,
`myAssignmentsProvider`, `assignmentByIdProvider(id)`, `clubPagesProvider`,
`clubZoneProvider` (unknown / none / the zone), `refreshFailedProvider`.

### Models

| File | Purpose |
|---|---|
| `lib/models/assignment.dart` | Mirrors `assignments_v`. `doneCount`, `canSubmit`, `isReadOnly`, `isTerminal`, `isToday`, `isOnDay` (start to `endDate`), `roundTitleEn/Ar`; `assigneeId` (the owner) is null until someone claims it |
| `lib/models/assignment_item.dart` | Mirrors `assignment_items`. `isSatisfied`, `isFollowUp`, `answer`, `correct`, `flaggedAnswer/At` |
| `lib/models/profile.dart` | Mirrors `profiles`, plus the role's name in both languages from `/me`'s `access` |
| `lib/models/club_zone.dart` | `ClubZone` (lat, lng, radius) and `ClubZoneState`: `ZoneUnknown` (never synced: blocks), `NoZone`, `HasZone`; pure `clubZoneState()` |

### Features

| File | Purpose |
|---|---|
| `features/auth/splash_screen.dart` | Restores session, loads profile, applies locale, routes |
| `features/auth/login_screen.dart` | Phone (or, via the switch, email) + password. Ink header, language toggle, RTL-safe phone row, locked / no-access messages |
| `features/splash_handoff.dart` | The hand-off mixin + shared flags/durations |
| `features/locale_provider.dart` | `localeProvider`, persisted to the `settings` table |
| `features/home/home_screen.dart` | Stat tiles, today's round summary, Next up, pull-to-refresh |
| `features/home/home_header.dart` | Animated logo/text overlay + shared `HeaderText` |
| `features/assignments/list_screen.dart` | Three tabs (`tabFor` — `follow_up` is always Today), search (`matchesQuery`) |
| `features/assignments/detail_screen.dart` | The checklist. `normalizeAnswer`, `isItemChecked`, `itemPhotos`, `missingPhotoCount`, `canSubmitStaged` (staged answers, not ticks; the follow-up resubmit gate) |
| `features/assignments/club_zone.dart` | The zone check: pure `insideClub`, `checkClubZone` (permission, service, one fresh fix; never throws; no last-known fallback), `ensureLocationPermission` (Home's up-front prompt). The gate itself is `_zoneGate` in `detail_screen.dart`, re-checked in `_submit` |
| `features/assignments/signature_screen.dart` | Signature pad, forced LTR. Drains, then re-reads the round *before* Success |
| `features/assignments/success_screen.dart` | Confirmation, names the submitted round. A second face for `follow_up` ("Sent — needs follow-up") |
| `features/assignments/history_detail_screen.dart` | Read-only view of a submitted round, with each item's answer |
| `features/profile/profile_screen.dart` | Phone, language toggle (`set_locale` RPC), About and Policies (the admin's `club_pages` text, else the built-in line), logout |

### Shared widgets (`lib/widgets/`)

`app_header.dart` (the ink block — one owner of colour/radius/logo/height, plus
`HeaderIconButton`) · `error_snack.dart` (the one place a failure the user is waiting on becomes visible) · `app_nav_bar.dart` (floating 3-tab bar + `navBarExtent()`
— **every scrollable branch owes its last row this much bottom padding**) ·
`ink_handoff_panel.dart` · `brand_logo/panel/wordmark.dart` ·
`language_toggle.dart` · `status_chip.dart` (7 statuses + extended marker) ·
`task_card.dart` (round-title kicker) · `task_progress_bar.dart` (owns
done/total arithmetic; `fillFor(status)`) · `subtask_tile.dart` (the answer
control per item type — Yes/No or Pass/Fail pair, number field forced LTR,
text field — and the follow-up note; the tile body no longer toggles) ·
`photo_thumb.dart` (a queued file from disk, a stored path through the signed
link `GET /assignments/:id` returns; a clip shows as a play tile) ·
`evidence_video.dart` (`isVideoPath`, `VideoTile`, full-screen player with
`video_player`) · `sync_banner.dart` (offline / sending / needs attention, and
the Retry / Dismiss sheet).

### Localization (`lib/l10n/`)

116 keys in `app_en.arb` / `app_ar.arb`, both complete (`untranslated.txt` is
`{}`). `app_localizations*.dart` are **generated** — edit the `.arb` files and
run `flutter gen-l10n`. `localized_text.dart` is hand-written:
`pickLocalized()` (EN/AR column pair with fallback), `formatWindow()`,
`assignmentSubtitle()` (round title first), `formatAnswer()` (yes/no and
pass/fail keywords → localized words), `formatCorrect()` (a `correct` rule as
the expected answer: "Yes", "1–3", "≥ 1"; words in Arabic).

---

## 5. Backend (`supabase/migrations/`)

| File | Applied? | What |
|---|---|---|
| `0001_ohouse_app.sql` | yes | The big one. Purely additive, re-runnable, backs up first |
| `0001_verify.sql` | — | Post-migration assertions, self-rolling-back |
| `0002_storage_scoping.sql` | **NO — draft** | Path-ownership RLS for uploads |
| `0003_handle_new_user_phone.sql` | yes | Copy `phone` into `profiles` |
| `0004_synthetic_email_fallback.sql` | yes | Extract real phone from `@ohouse.internal` |
| `0005_profile_self_update_rpc.sql` | yes | `set_locale()` RPC |
| `0006_partial_submit.sql` | yes | `submit_assignment()` accepts a partial round |
| `0007`–`0012` | — | Portal-side hardening (fail-closed RPC guards, the inspector portal, phone privacy). **These files live in the admin repo**, `o-house-admin/supabase/migrations/`, not here |
| `0013_rounds_follow_up.sql` | yes (live) | **Also in the admin repo**: `o-house-admin/supabase/migrations/0013_rounds_follow_up.sql` (+ `0013_verify.sql`). Zone rounds, answer capture, correct answers and `follow_up` — see below |

Migrations live in two repos now: this one up to 0006, `o-house-admin` from
0007. Check both before assuming the live schema.

### Vocabulary trap

The table is `submissions`, not `assignments`, and `inspector_id` means "the
owner" (the assignee who claimed it; NULL until then — the full list is
`assignee_ids`). Both names were kept so the live admin dashboard's queries
don't 404. `submissions.answers` is **deprecated** (kept for 4 legacy rows) —
live checklist state is in `assignment_items`.

### Schema

- `profiles` — + `phone` (partial-unique), `active`, `must_change_password`,
  `locale`, roles widened to `admin|manager|inspector|cleaner`
- `submissions` — + lifecycle, `scheduled_date`, `window_start/end`,
  `extended_until`, `client_id` (idempotency), `late_sync`, `signature_url`,
  `round_id` (0013). Status adds `follow_up` (0013)
- `assignment_items` — the checklist, promoted out of JSON. Column names mirror
  `templates.items` keys exactly. RLS: **SELECT only**. Since 0013:
  `correct jsonb` (null = no rule; `{"eq": "yes"|"no"|"pass"|"fail"|"<text>"}`
  or `{"min": n, "max": n}`, either bound optional), `answer` (the latest),
  `flagged_answer` + `flagged_at` (the first wrong answer, kept as history).
  Status `pending | done | rejected | follow_up`
- `round_templates`, `rounds` (0013) — zone rounds, managed from the portal.
  The app only sees a round's title, through the view
- `device_tokens` — FCM push targets (unused so far)
- `assignments_v` — the view the app reads. **Always read `effective_status`,
  never `status`.** Expiry is derived from the clock, not stored; handles
  overnight windows; `Africa/Cairo` throughout. `follow_up` is **never**
  clock-expired. + `round_id`, `round_title_en/ar` (null outside a round)

### RPCs (all `SECURITY DEFINER`, revoked from `anon`)

`create_assignment` · `mark_item_done` · `attach_item_photo` ·
`submit_assignment` (the real trust boundary — the disabled Submit button is
convenience only) · `extend_assignment` · `reject_items` ·
`approve_assignment` · `set_locale` · `schedule_rounds` (portal only).
`answer_ok()` is not one of them: a plain immutable helper the answer RPCs
call, not executable by clients.

### Answers and follow-up (0013)

- `mark_item_done(p_item_id, p_note, p_answer)` stores the answer and judges
  it with `answer_ok()`: no rule, or a matching answer → `done`; a wrong **or
  missing** answer on a rule item → `follow_up`. It never raises over an
  answer — an unknown error would jam the outbox. The app sends `answer`
  only when it has one (the queued `answer` op, through the API).
- Wire values: yesno `yes`/`no`, pass_fail `pass`/`fail`, number a decimal
  string with Arabic digits and `٫`/`,` folded (`normalizeAnswer`), text
  trimmed. Text compares case- and space-insensitively server-side.
- `submit_assignment` counts `done` and `follow_up` items as answered (for
  `EMPTY_SUBMISSION:`/`MISSING_PHOTO:`); any `follow_up` item puts the round
  in `follow_up`, else `submitted`. A `follow_up` round has no deadline, can
  be resubmitted after re-answering some flagged items (partial fixes are
  allowed), and keeps its first `submitted_at`/`late_sync`.
- In the app a `follow_up` item is editable and counts as **unanswered**
  until re-answered; the expected answer is shown only on flagged items;
  resubmitting a `follow_up` round needs at least one fresh answer.
- Rollout order matters: an app older than this one sends no answer, so any
  item with a rule would flag. Set correct answers only once staff update.

### Sign-in

Since 27 Sep the API owns sign-in (`user_logins`, `refresh_tokens`); Supabase
Auth is no longer used. A login is a phone number (10 digits → `+20…`) or an
email. The old `20XXXXXXXXX@ohouse.internal` accounts were copied over as
phone logins with their password hashes, so nobody had to reset a password.

### Storage

One bucket, `checklist-media` (going private at plan Step 4). Since Step 3 the
app never touches Storage: it sends the file to the API, which stores it at
`photos/{assignment_id}/{item_id}-{photoId}.jpg` (`.mp4` for a video, ≤ 50 MB)
or `signatures/{assignment_id}-{signatureId}.png`, from ids fixed at capture,
so a replay writes the same object.

---

## 6. Design system — "Broadsheet"

Source: `.design-preview-tmp/_ds/broadsheet-*/styles.css` and
`design_handoff_o_house_app/design-tokens.json`. Screens map to artboards
(1c = tasks list, 1d = task detail, 1h = success, 1i = history).

- Palette lives **only** in `AppColors`, named by role not hue. `magenta` is
  reserved for the alarm states — rejected, overdue, follow-up — and nothing
  else may use it. A "No" or "Fail" answer is *not* an alarm; picked, it is
  cyan like any other choice.
- **The brand roles are per club** (`lib/tenant.dart`, 30 Sep), from the
  members' app palettes by one rule: `ink` = primary 500, `cyan` = secondary
  500, `cyanDark` = the lightest secondary shade from 600 at 4.5:1 on paper,
  `cyanTint` = secondary 50, `onCyan` = white unless that is under 3:1 on cyan
  (RYZE's orange is 2.1:1), then ink. "cyan" is the role name; for RYZE and
  KODE it is orange. Text on a cyan fill uses `onCyan`, never `paper`; text on
  paper uses `cyanDark`, never `cyan` (the nav label, `TextButton`s through
  `textButtonTheme`). `tenant_test.dart` checks these contrasts for every club.
- Fonts: Montserrat (the clubs' brand face, the same files as the members'
  app) with Noto Naskh Arabic as `fontFamilyFallback`. One `TextTheme` serves
  both locales, with no per-locale branch. The portal uses Cairo for Arabic;
  bundling Cairo here too is open. Button text lives on `TextTheme.labelLarge`, **not**
  `filledButtonTheme.textStyle` (ButtonStyle replaces rather than merges, and
  Arabic renders as tofu).
- Radii: `kRadius` 2px (cards, flat by spec), `kRadiusControl` 16px
  (interactive controls), `kRadiusHeader` 28px bottom-only,
  `kRadiusFloating` 20px (nav bar + tiles — a placeholder, not in the tokens).
- `kControlHeight` 56 · `kHeaderContentHeight` 140 (a floor, not a fixed size).

---

## 7. Tests (`test/`, 135 tests, all passing)

| File | Covers |
|---|---|
| `tasks_logic_test.dart` | Pure logic: `tabFor` (asserted as a *total* partition — a bug there hides work rather than erroring; `follow_up` → Today whatever its date), `matchesQuery`, `normalizeAnswer` (Arabic-Indic digits, `٫`, `,`), answer-based staging, `canSubmitStaged` incl. the follow-up resubmit gate, `itemPhotos` |
| `outbox_test.dart` | The refusal contract as the phone reads it (`classifyResponse`), the 401 refresh-and-retry, and SyncService against fakes: per-round order, a 503 stops one round, no response stops all, parking + Retry, evidence deleted only after a 2xx, MISSING_FILE, user scoping, the rerun flag, refresh after a send; `backoff`, `applyLocal`, `isoWithOffset`, `RoundDraft`, `syntheticEmailToPhone` |
| `submit_sync_test.dart` | The signature flow: queue then drain, success built on the re-read, a refused round reports why and goes Home instead of claiming success, the supervisor note travels with the submit, an empty pad does nothing |
| `club_pages_test.dart` | Profile's About / Policies: the admin's text in the reader's language, the other language when one is empty, the built-in line when nothing is written |
| `push_test.dart` | `routeFor`: where a tapped push opens (a round, Tasks, Home, nothing for malformed data); the device token goes up with PUT and comes back with an encoded DELETE |
| `club_zone_test.dart` | `insideClub` (inside, outside, mocked, no zone), the `/me` shape, and `clubZoneState`: never synced blocks, synced with no zone has no gate, a cached zone is the zone |
| `role_label_test.dart` | The header's role name: en/ar pick, fallback to the role key when `/me` has no `access` |
| `tenant_test.dart` | `resolveTenant` fails fast (missing, unknown, mismatched `TENANT_NAME`), every tenant config is complete and its logo file exists, every tenant's brand contrasts (cyanDark on paper ≥ 4.5, paper on ink ≥ 4.5, onAccent on accent ≥ 3), the API client sends the tenant's club, OWEST's palette colours |
| `app_header_test.dart` | Header height/logo consistency across every screen in both locales; submission flow; signature button and pad sizing |
| `home_screen_test.dart` | Stat counts, today-filter, Next up ordering, ink hand-off cases, pull-to-refresh |
| `tasks_screens_test.dart` | Both dense screens pumped at real phone width in EN *and* AR — a widget test fails on RenderFlex overflow, which is the cheap way to keep Arabic honest. Also a `follow_up` round built in-test (the fixtures stay untouched): the flag note, Yes/No and number inputs (Arabic digits), the resubmit gate, LTR number field under RTL, and the success screen's follow-up face |
| `login_screen_test.dart` | Empty-field guard, password reveal, LTR phone row under RTL |
| `theme_test.dart` | Theme invariants |

Layout, camera and live network paths are verified manually by design.

---

## 8. Conventions

- **Comments explain *why*, at length.** This codebase's comments are
  load-bearing — they record decisions and rejected alternatives. Match that
  when editing.
- `ponytail:` comments mark deliberate shortcuts with a named ceiling and an
  upgrade path. `TODO(phase-N)` marks deferred phase work. Grep for both.
- Read `effective_status`, never `status`.
- No screen touches Supabase for assignment data — go through `AssignmentsRepo`.
- Every scrollable inside the shell needs `navBarExtent(context)` bottom padding.
- The signature pad, the phone-number row and the number answer field are
  forced LTR regardless of locale.
- There is deliberately **no way to delete a photo** — `attach_item_photo` is
  `array_append` server-side and nothing removes from it. Evidence, once taken,
  stands.
- Camera only, never gallery — a gallery photo isn't evidence.

---

## 9. Suggested next steps

1. Commit the working tree (it's a whole app's worth of work).
2. Apply `0006_partial_submit.sql` in the Supabase SQL editor.
3. Phase 2: compress photos before queuing — 10 staff × 40 places × one 4MB
   photo is 1.6GB/day uncompressed.
4. Phase 3: optimistic local updates + cache-first reads.
5. Phase 4: surface terminal sync rejections to the user.
6. Apply `0002_storage_scoping.sql` before this app has any outside reach.
7. Real `applicationId` (`com.blueribbon.<newapp>.owest`) before any release build.

## 10. Clubs (one app per club, same code)

The tenant method of the members' app, Android only. Three clubs (30 Sep):

| Flavor | API slug | App name | applicationId (temporary) | Icon |
|---|---|---|---|---|
| `owest` | `ohouse` | O House | `com.example.o_house` | the members' app O West icon |
| `ryze` | `ryze` | RYZE House | `com.example.o_house.ryze` | the members' app RYZE icon |
| `kode` | `kode` | KODE House | `com.example.o_house.kode` | the K mark (`kode.png`) on KODE blue |

Distinct temporary ids so all three install side by side on one test phone;
all become `com.blueribbon.<newapp>.<club>` at the app ID decision. RYZE and
KODE have no Supabase project yet, so their apps can sign in only against a
local API whose `CLUBS` has a dev-only entry for them. The club names
("RYZE" / "KODE") are placeholders, `TODO(club names)` in `tenant.dart`.

- **Native identity:** a flavor per club in `android/app/build.gradle.kts`
  (`applicationId`, `app_name`), icons in `android/app/src/<tenant>/res/`,
  from Step 5 `google-services.json` there too, release signing from a
  gitignored `android/<tenant>.properties` (debug keys without it).
- **Dart:** `lib/tenant.dart`. Only public values: the Supabase secret key
  lives in the API alone. Brand colours (`AppColors.ink/cyan/cyanDark/cyanTint/onCyan`)
  come from the tenant (see §6 for the rule); magenta and the neutrals are shared.
- **Assets:** `assets/tenants/<tenant>/<tenant>.png`, light artwork on a
  transparent ground (it only ever sits on the ink header). Every club's logo
  ships in every build.
- **Running another club:** `tool\run_dev.ps1 -Flavor ryze` (dev), or
  `--flavor kode --dart-define=TENANT_NAME=KODE`. A build for the Railway test
  API adds `--dart-define=ENVIRONMENT=prod --dart-define=API_URL=https://o-house-api-production.up.railway.app`.
- **Tests** run as OWEST (`test/flutter_test_config.dart`) and override
  `userIdProvider` to signed-out, since there is no Supabase in tests.
- **Adding a club:** enum value + `TenantConfig` + `assets/tenants/<t>/`;
  flavor block, icons, `google-services.json`, `<t>.properties`; its entry in
  the API's `CLUBS`; a Play listing under the confirmed package name.
