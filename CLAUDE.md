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

```bash
flutter run
```

| Task | Command |
|---|---|
| Tests | `flutter test` |
| Analyze | `flutter analyze` (clean as of last check) |
| Regenerate l10n | `flutter gen-l10n` (config in `l10n.yaml`) |
| Screen preview, no login | `flutter run -t lib/main_dev_preview.dart` |

**Browser preview** (visual verification): `flutter run -d web-server` renders a
black canvas for this project. What works is `flutter build web --release`
(~4 min) then serving `build/web` over a static HTTP server. Note `sqflite` has
no web implementation, so anything touching `LocalDb` silently no-ops there.

`main_dev_preview.dart` is a throwaway entrypoint that mounts one screen with
fake data: `?screen=home|tasks|profile`, `?lang=ar`.

---

## 2. Current state — READ THIS FIRST

**Branch `rounds-follow-up-tracker`.** Commit `8f4202a` checkpoints the whole
Home, Tasks, Task detail, Signature, Success, History and Profile build (and
the shared `widgets/` extraction and its tests) on top of `1bdfff3` ("Finishing
- Splash & Login"); `main` still stops at `1bdfff3`. The answers / follow-up /
zone-round work (migration 0013) sits uncommitted on top of `8f4202a`.

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
| 3 | Offline writes: outbox drain, optimistic local updates, cache reads | **Code done (plan Step 3)** — every read and write goes through the O House API (`data/api_client.dart`); cache-first providers; SyncService v2 (per-round order, backoff, parking with Retry/Dismiss, user-scoped); club code + one database per club. Not yet run on a device against a deployed API |
| 4 | Push notifications | **Not started** — `firebase_core`/`firebase_messaging` in pubspec, zero Dart references, no `google-services.json` |

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
   app on the first photo. Ship blocker on iOS.

---

## 3. Architecture

```
main.dart → initSupabase() → ProviderScope → OHouseApp (app.dart)
                                                  ↓
                                       MaterialApp.router + buildTheme()
                                                  ↓
                                            router.dart (go_router)
```

- **State**: Riverpod. All providers live in `lib/data/providers.dart`.
- **Since Step 3 the app never reaches the database or Storage.** Every read
  and write is HTTPS to the O House API (`data/api_client.dart`, `X-Club` on
  every call). `supabase_flutter` is for sign-in only, initialized per club
  (`club.dart`: the club code → `GET /clubs/:code` → that club's project).
- **The one seam**: `AssignmentsRepo`. No screen touches the API directly
  (Profile's locale and set-password's `password-changed` are the exceptions).
- **Cache first** (LS-3): `myAssignmentsProvider` reads the per-user cache and
  lays queued work over it (`applyLocal`); `roundsRefreshProvider` does the
  `GET /assignments`. One SQLite file per club; every row carries its user.
- **Offline shape**: writes are enqueued (`answer` / `photo` / `submit`, ids
  fixed at capture, evidence in `documents/evidence/<club>/`). `SyncService`
  sends them per round in order; a 422 `refused` parks the op (banner → Retry /
  Dismiss), everything else retries with backoff. See `data/sync.dart`.

### Routes (`lib/router.dart`)

| Path | Screen | Notes |
|---|---|---|
| `/splash` | `SplashScreen` | Cold boot only. Owns the routing decision. |
| `/login` | `LoginScreen` | `NoTransitionPage` — owns its own ink animation |
| `/set-password` | `SetPasswordScreen` | Forced when `must_change_password` |
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
| `lib/main.dart` | Boot: portrait lock, `initSupabase()`, `ProviderScope` |
| `lib/app.dart` | `MaterialApp.router`, theme, locale, l10n delegates |
| `lib/router.dart` | All routes + auth redirect + `GoRouterRefreshStream` |
| `lib/supabase.dart` | Client init, re-exports `supabase_flutter`, `phoneToSyntheticEmail()` |
| `lib/theme.dart` | `AppColors`, radii, shadows, `buildTheme()` |
| `lib/main_dev_preview.dart` | Throwaway screen-preview entrypoint |

### Data

| File | Purpose |
|---|---|
| `lib/data/providers.dart` | Every Riverpod provider |
| `lib/data/assignments_repo.dart` | **The seam.** Reads/refresh/writes + demo-mode branch. Refresh fetches the last 7 days plus anything in `follow_up`, items in chunks of 50 rounds |
| `lib/data/local_db.dart` | sqflite: `cached_assignments`, `outbox`, `settings` |
| `lib/data/sync.dart` | Outbox drain, storage upload, `isTerminalError`, `buildStoragePath`, `markItemDoneParams` |
| `lib/data/fixtures.dart` | Demo data behind `kDemoData` (currently `false`) |

Providers: `localDbProvider`, `assignmentsRepoProvider`, `syncServiceProvider`,
`outboxCountProvider`, `authStateProvider`, `currentProfileProvider`,
`myAssignmentsProvider`, `assignmentByIdProvider(id)`.

### Models

| File | Purpose |
|---|---|
| `lib/models/assignment.dart` | Mirrors `assignments_v`. `doneCount`, `canSubmit`, `isReadOnly`, `isTerminal`, `isToday`, `roundTitleEn/Ar` |
| `lib/models/assignment_item.dart` | Mirrors `assignment_items`. `isSatisfied`, `isFollowUp`, `answer`, `correct`, `flaggedAnswer/At` |
| `lib/models/profile.dart` | Mirrors `profiles` |

### Features

| File | Purpose |
|---|---|
| `features/auth/splash_screen.dart` | Restores session, loads profile, applies locale, routes |
| `features/auth/login_screen.dart` | Phone + password. Ink header, language toggle, RTL-safe phone row |
| `features/auth/set_password_screen.dart` | Forced first-login / post-reset change |
| `features/splash_handoff.dart` | The hand-off mixin + shared flags/durations |
| `features/locale_provider.dart` | `localeProvider`, persisted to the `settings` table |
| `features/home/home_screen.dart` | Stat tiles, today's round summary, Next up, pull-to-refresh |
| `features/home/home_header.dart` | Animated logo/text overlay + shared `HeaderText` |
| `features/assignments/list_screen.dart` | Three tabs (`tabFor` — `follow_up` is always Today), search (`matchesQuery`) |
| `features/assignments/detail_screen.dart` | The checklist. `normalizeAnswer`, `isItemChecked`, `itemPhotos`, `missingPhotoCount`, `canSubmitStaged` (staged answers, not ticks; the follow-up resubmit gate) |
| `features/assignments/signature_screen.dart` | Signature pad, forced LTR. Drains, then re-reads the round *before* Success |
| `features/assignments/success_screen.dart` | Confirmation, names the submitted round. A second face for `follow_up` ("Sent — needs follow-up") |
| `features/assignments/history_detail_screen.dart` | Read-only view of a submitted round, with each item's answer |
| `features/profile/profile_screen.dart` | Phone, language toggle (`set_locale` RPC), about, policies, logout |

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
`photo_thumb.dart` (resolves a device path, a bucket path or a full URL via
`mediaUrl`) · `sync_banner.dart`.

### Localization (`lib/l10n/`)

91 keys in `app_en.arb` / `app_ar.arb`, both complete (`untranslated.txt` is
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
person assigned". Both names were kept so the live admin dashboard's queries
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
  answer — an unknown error would jam the outbox. The app sends `p_answer`
  only when it has one (`markItemDoneParams`), so pre-0013 queued rows still
  replay.
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

### Auth quirk

The project's Phone provider is **not enabled** (no SMS provider). Staff sign
in with a phone number that maps to a disguised email —
`phoneToSyntheticEmail()` in `lib/supabase.dart` → `20XXXXXXXXX@ohouse.internal`
(`.internal` is IETF-reserved). The UI never says "email". If real phone auth
is ever switched on, only that function and its one call site change.

### Storage

One bucket, `checklist-media`, **public**. Paths: `photos/{assignment_id}/{item_id}-{µs}.jpg`,
`signatures/{assignment_id}-{µs}.png`. `buildStoragePath()` is unit-tested
because `0002`'s RLS policy structurally depends on that exact shape. Uploads
use `upsert: true` so replay is idempotent.

---

## 6. Design system — "Broadsheet"

Source: `.design-preview-tmp/_ds/broadsheet-*/styles.css` and
`design_handoff_o_house_app/design-tokens.json`. Screens map to artboards
(1c = tasks list, 1d = task detail, 1h = success, 1i = history).

- Palette lives **only** in `AppColors`, named by role not hue. `magenta` is
  reserved for the alarm states — rejected, overdue, follow-up — and nothing
  else may use it. A "No" or "Fail" answer is *not* an alarm; picked, it is
  cyan like any other choice.
- Fonts: Source Serif 4 (Latin) with Noto Naskh Arabic as
  `fontFamilyFallback` — one `TextTheme` serves both locales, no per-locale
  branch. Button text lives on `TextTheme.labelLarge`, **not**
  `filledButtonTheme.textStyle` (ButtonStyle replaces rather than merges, and
  Arabic renders as tofu).
- Radii: `kRadius` 2px (cards, flat by spec), `kRadiusControl` 16px
  (interactive controls), `kRadiusHeader` 28px bottom-only,
  `kRadiusFloating` 20px (nav bar + tiles — a placeholder, not in the tokens).
- `kControlHeight` 56 · `kHeaderContentHeight` 140 (a floor, not a fixed size).

---

## 7. Tests (`test/`, 98 tests, all passing)

| File | Covers |
|---|---|
| `tasks_logic_test.dart` | Pure logic: `tabFor` (asserted as a *total* partition — a bug there hides work rather than erroring; `follow_up` → Today whatever its date), `matchesQuery`, `normalizeAnswer` (Arabic-Indic digits, `٫`, `,`), answer-based staging, `canSubmitStaged` incl. the follow-up resubmit gate, `itemPhotos` |
| `outbox_test.dart` | `isTerminalError` (terminal vs. retryable RPC failures), `buildStoragePath`, `mediaUrl`; `p_answer` in the queued `mark_item_done` payload (through the real repo, with a capturing `LocalDb`) and in `markItemDoneParams` only when non-null |
| `submit_sync_test.dart` | That submitting drains the outbox, drains *after* the enqueue, scopes the drain to its own round, re-reads the round *before* the success screen is built, and — the lie that hid the bug — never shows the success screen when the queue stopped |
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
7. Real `applicationId` before any release build.
