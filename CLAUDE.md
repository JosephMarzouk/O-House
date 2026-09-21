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

**Everything past commit `1bdfff3` ("Finishing - Splash & Login") is
uncommitted.** That commit only covers splash + login. The entire Home, Tasks,
Task detail, Signature, Success, History and Profile build — plus the shared
`widgets/` extraction and 5 of the 7 test files — is sitting in the working
tree. `git status` will show ~28 modified/deleted and ~13 untracked files.
Commit before doing anything destructive.

Deleted-but-not-staged (refactored away, do not resurrect):
`lib/features/assignments/item_sheet.dart` → folded into `subtask_tile.dart`;
`lib/features/auth/custom_widgets/LanguageToggle.dart` → `lib/widgets/language_toggle.dart`;
`lib/main_dev_home_preview.dart` → `lib/main_dev_preview.dart`;
`.claude/launch.json`.

### Phase status

| Phase | Scope | State |
|---|---|---|
| 1 | Online-only reads/writes, all screens | **Done** |
| 2 | Image compression before queuing | **Not started** — `flutter_image_compress` is in pubspec, unused |
| 3 | Offline writes: outbox drain, optimistic local updates, cache reads | **Partial** — the outbox now actually drains (the signature screen drains before it invalidates), but reads still go straight to the server and never fall back to the cache |
| 4 | Push notifications | **Not started** — `firebase_core`/`firebase_messaging` in pubspec, zero Dart references, no `google-services.json` |

### Known issues

1. **Offline reads are broken, and the cache is write-only.**
   `myAssignmentsProvider` always calls `refreshFromServer`;
   `AssignmentsRepo.myAssignments()` (the cache read) is only reachable when
   `kDemoData` is true. Offline the provider errors and every screen renders
   `valueOrNull ?? []` — "you have no tasks" — and a deep-linked task detail
   spins forever. A fix must also solve two things: `currentProfileProvider` is
   itself a network `select()` awaited first, and `myAssignments()` has no
   assignee filter, so a naive cache read leaks one staff member's rounds to
   the next on a shared device.
2. **Retrying Submit duplicates photo evidence.** `detail_screen._submit`
   re-enables itself when the signature route pops and never clears
   `_newPhotos`/`_checked`. Back out of signing, tap Submit again, and the same
   file is enqueued twice under two `microsecondsSinceEpoch` paths — defeating
   `attach_item_photo`'s `not (p_storage_path = any(photo_paths))` guard. There
   is deliberately no way to delete a photo, so it is permanent.
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
- **The one seam**: `AssignmentsRepo`. **No screen touches Supabase directly**
  for assignment data. (Auth and the `set_locale` RPC are the exceptions —
  login/profile call `supabase` directly.)
- **Writes are RPCs, never table writes.** Every mutation goes through a
  `SECURITY DEFINER` Postgres function. `profiles` has no client UPDATE grant.
- **Offline shape**: writes are enqueued into a SQLite `outbox` (one row =
  one RPC call + payload); `SyncService.drain()` replays them FIFO per
  assignment so photos and signature land *before* `submit_assignment`.

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
| `lib/data/assignments_repo.dart` | **The seam.** Reads/refresh/writes + demo-mode branch |
| `lib/data/local_db.dart` | sqflite: `cached_assignments`, `outbox`, `settings` |
| `lib/data/sync.dart` | Outbox drain, storage upload, `isTerminalError`, `buildStoragePath` |
| `lib/data/fixtures.dart` | Demo data behind `kDemoData` (currently `false`) |

Providers: `localDbProvider`, `assignmentsRepoProvider`, `syncServiceProvider`,
`outboxCountProvider`, `authStateProvider`, `currentProfileProvider`,
`myAssignmentsProvider`, `assignmentByIdProvider(id)`.

### Models

| File | Purpose |
|---|---|
| `lib/models/assignment.dart` | Mirrors `assignments_v`. `doneCount`, `canSubmit`, `isReadOnly`, `isTerminal`, `isToday` |
| `lib/models/assignment_item.dart` | Mirrors `assignment_items`. `isSatisfied` |
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
| `features/assignments/list_screen.dart` | Three tabs (`tabFor`), search (`matchesQuery`) |
| `features/assignments/detail_screen.dart` | The checklist. `isItemChecked`, `itemPhotos`, `missingPhotoCount`, `canSubmitStaged` |
| `features/assignments/signature_screen.dart` | Signature pad, forced LTR |
| `features/assignments/success_screen.dart` | Confirmation, names the submitted round |
| `features/assignments/history_detail_screen.dart` | Read-only view of a submitted round |
| `features/profile/profile_screen.dart` | Phone, language toggle (`set_locale` RPC), about, policies, logout |

### Shared widgets (`lib/widgets/`)

`app_header.dart` (the ink block — one owner of colour/radius/logo/height, plus
`HeaderIconButton`) · `error_snack.dart` (the one place a failure the user is waiting on becomes visible) · `app_nav_bar.dart` (floating 3-tab bar + `navBarExtent()`
— **every scrollable branch owes its last row this much bottom padding**) ·
`ink_handoff_panel.dart` · `brand_logo/panel/wordmark.dart` ·
`language_toggle.dart` · `status_chip.dart` (6 statuses + extended marker) ·
`task_card.dart` · `task_progress_bar.dart` (owns done/total arithmetic;
`fillFor(status)`) · `subtask_tile.dart` · `photo_thumb.dart` (resolves a device path, a bucket path
or a full URL via `mediaUrl`) · `sync_banner.dart`.

### Localization (`lib/l10n/`)

86 keys in `app_en.arb` / `app_ar.arb`, both complete (`untranslated.txt` is
`{}`). `app_localizations*.dart` are **generated** — edit the `.arb` files and
run `flutter gen-l10n`. `localized_text.dart` is hand-written:
`pickLocalized()` (EN/AR column pair with fallback), `formatWindow()`,
`assignmentSubtitle()`.

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

### Vocabulary trap

The table is `submissions`, not `assignments`, and `inspector_id` means "the
person assigned". Both names were kept so the live admin dashboard's queries
don't 404. `submissions.answers` is **deprecated** (kept for 4 legacy rows) —
live checklist state is in `assignment_items`.

### Schema

- `profiles` — + `phone` (partial-unique), `active`, `must_change_password`,
  `locale`, roles widened to `admin|manager|inspector|cleaner`
- `submissions` — + lifecycle, `scheduled_date`, `window_start/end`,
  `extended_until`, `client_id` (idempotency), `late_sync`, `signature_url`
- `assignment_items` — the checklist, promoted out of JSON. Column names mirror
  `templates.items` keys exactly. RLS: **SELECT only**
- `device_tokens` — FCM push targets (unused so far)
- `assignments_v` — the view the app reads. **Always read `effective_status`,
  never `status`.** Expiry is derived from the clock, not stored; handles
  overnight windows; `Africa/Cairo` throughout

### RPCs (all `SECURITY DEFINER`, revoked from `anon`)

`create_assignment` · `mark_item_done` · `attach_item_photo` ·
`submit_assignment` (the real trust boundary — the disabled Submit button is
convenience only) · `extend_assignment` · `reject_items` ·
`approve_assignment` · `set_locale`

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
  reserved for rejected/overdue and nothing else may use it.
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

## 7. Tests (`test/`, 72 tests, all passing)

| File | Covers |
|---|---|
| `tasks_logic_test.dart` | Pure logic: `tabFor` (asserted as a *total* partition — a bug there hides work rather than erroring), `matchesQuery`, `canSubmitStaged`, `itemPhotos` |
| `outbox_test.dart` | `isTerminalError` (terminal vs. retryable RPC failures), `buildStoragePath`, `mediaUrl` |
| `submit_sync_test.dart` | That submitting drains the outbox, drains *after* the enqueue, scopes the drain to its own round, and — the lie that hid the bug — never shows the success screen when the queue stopped |
| `app_header_test.dart` | Header height/logo consistency across every screen in both locales; submission flow; signature button and pad sizing |
| `home_screen_test.dart` | Stat counts, today-filter, Next up ordering, ink hand-off cases, pull-to-refresh |
| `tasks_screens_test.dart` | Both dense screens pumped at real phone width in EN *and* AR — a widget test fails on RenderFlex overflow, which is the cheap way to keep Arabic honest |
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
- The signature pad and the phone-number row are forced LTR regardless of locale.
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
