# Tasks: Session Countdown & Post-Attendance WhatsApp Report

**Input**: Design documents from `specs/001-attendance-timer-whatsapp/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Not included — this project has no automated test suite (see plan.md Technical Context); validation is manual via `quickstart.md` plus `flutter analyze`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

## Phase 1: Setup

- [X] T001 Add `DEFAULT_SESSION_MINUTES` (int, value `60`) and `SETTING_REPORT_ON_COMPLETION_ENABLED` (setting key string) constants in `lib/config/constants.dart`

---

## Phase 2: Foundational (blocking prerequisite for US2)

**Purpose**: The report-on-completion toggle's underlying state must exist before the send action (US2) can read/gate on it. This is plumbing only — no visible UI yet (the visible Settings control is US3).

- [X] T002 Add `RxBool reportOnCompletionEnabled` to `SettingsController` (`lib/controllers/settings_controller.dart`), defaulted to `false`, loaded via the existing `_dbService.getSetting(SETTING_REPORT_ON_COMPLETION_ENABLED)` pattern (mirror `whatsappEnabled`), with a `setReportOnCompletionEnabled(bool)` setter that persists via the existing `_dbService.setSetting` pattern

**Checkpoint**: `SettingsController.reportOnCompletionEnabled` exists and defaults to `false` — US1 can start immediately (no dependency on this); US2 can now be gated correctly once built.

---

## Phase 3: User Story 1 - See how much time is left in the current session (Priority: P1) 🎯 MVP

**Goal**: A countdown of remaining time appears inline on a group's attendance card whenever that group's scheduled session is currently running, and disappears otherwise.

**Independent Test**: Open the attendance screen while a group's scheduled session window is active; confirm the countdown is visible and ticking; confirm it disappears once the session's computed end time passes or for a group with no active session.

### Implementation for User Story 1

- [X] T003 [US1] Add `SessionWindow`-style lookup method `Duration? remainingSessionTime(Group group, DateTime now)` to `AttendanceController` (`lib/controllers/attendance_controller.dart`), built on top of the existing `sessionTimeForGroupOnDay`/weekday-parsing logic, using `DEFAULT_SESSION_MINUTES` from T001 as the end-time fallback (per research.md §1–2)
- [X] T004 [US1] Add a `Timer.periodic` (30–60s interval) to `_AttendancePageState` in `lib/views/attendance/attendance_page.dart` that triggers a lightweight rebuild of the visible countdown values; cancel it in `dispose()` (mirror the existing `_statsTimer` pattern from `exam_grades_page.dart` per research.md §6)
- [X] T005 [US1] Add a small countdown chip/badge to `_GroupAttendanceCard`'s header in `lib/views/attendance/attendance_page.dart`, calling `remainingSessionTime` (T003) for that card's group; render nothing when the result is `null`
- [X] T006 [US1] Format the remaining `Duration` as `مم:ثث` or `س:مم` (over/under an hour) for display in the chip built in T005

**Checkpoint**: User Story 1 is fully functional and independently testable via `quickstart.md` Scenario 1 — ship/demo here if desired before continuing.

---

## Phase 4: User Story 2 - Notify guardians right after finishing attendance (Priority: P2)

**Goal**: Once every enrolled student in a group has an attendance mark for today, a "send WhatsApp report" action becomes available; triggering it shows a recipient summary, requires confirmation, then opens one `wa.me` chat per guardian (present and absent students alike) pre-filled with that student's attendance + homework status for today.

**Independent Test**: With the Phase 2 toggle forced to `true` for testing, mark attendance for every student in a group; confirm the send action appears only once complete; trigger it and confirm the confirmation summary, skip-count, and per-guardian message content match spec.md FR-010–FR-013.

### Implementation for User Story 2

- [X] T007 [US2] Add `bool isAttendanceCompleteForGroupToday(Group group, List<Student> groupStudents)` to `AttendanceController` (`lib/controllers/attendance_controller.dart`) per data-model.md's `GroupAttendanceCompletion` (enrolled student IDs vs. today's marked student IDs)
- [X] T008 [P] [US2] Add a `String buildGuardianReportMessage({required Student student, required Attendance todayAttendance, Homework? todayHomework})` text builder to `AttendanceController` (`lib/controllers/attendance_controller.dart`), producing the format from research.md §5 (name, date, attendance status, homework status or "لم يُسجَّل")
- [X] T009 [US2] Add a "send WhatsApp report" action to `_GroupAttendanceCard` in `lib/views/attendance/attendance_page.dart`, visible only when `isAttendanceCompleteForGroupToday` (T007) is true **and** `Get.find<SettingsController>().reportOnCompletionEnabled.value` is true (depends on T002, T007)
- [X] T010 [US2] Build a confirmation dialog/sheet (new widget in `lib/views/attendance/attendance_page.dart`) listing every enrolled student's guardian who will receive a message, plus a count of students skipped for missing `guardianPhone` (FR-011), with an explicit confirm button (FR-012 / Clarifications Q1 = A) — depends on T009
- [X] T011 [US2] Implement the confirmed send flow: iterate all enrolled students with a `guardianPhone` (present and absent alike, per FR-013 / Clarifications Q2 = A), build each message via T008, launch `https://wa.me/{phone}?text={encoded}` with `url_launcher` `LaunchMode.externalApplication`, and await app-resume between each guardian (reuse the existing `_waitForResume()`/`WidgetsBindingObserver` pattern from `settings_page.dart`, per research.md §4) — depends on T008, T010
- [X] T012 [US2] Add an in-memory (session-only, not persisted) "report already sent today" flag per group, set after a successful T011 run, that hides the send action from T009 until attendance is edited again for that group/day — addresses the spec.md Edge Case about stale reports after an attendance correction

**Checkpoint**: User Stories 1 AND 2 both work independently (with the toggle manually forced on for US2 testing) — validate via `quickstart.md` Scenario 3.

---

## Phase 5: User Story 3 - Turn the automatic-report feature on or off (Priority: P3)

**Goal**: A visible Settings toggle controls whether the User Story 2 send action ever appears, defaulting to off.

**Independent Test**: With the toggle off (fresh install default), confirm the send action never appears anywhere even with attendance fully marked. Turn it on from Settings; confirm the send action now appears. Turn it back off; confirm it disappears again.

### Implementation for User Story 3

- [X] T013 [US3] Add a toggle row (e.g. "إرسال تقرير واتساب تلقائي بعد اكتمال الحضور") to `lib/views/settings/settings_page.dart`, following the existing `whatsappEnabled`-style toggle pattern, bound to `SettingsController.reportOnCompletionEnabled` / `setReportOnCompletionEnabled` (T002)

**Checkpoint**: All three user stories are independently functional — validate full end-to-end via `quickstart.md` Scenario 2.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T014 [P] Run `flutter analyze` and resolve any new errors/warnings introduced by T001–T013 (project convention — zero-new-issues gate)
- [ ] T015 Walk through all three `quickstart.md` scenarios manually on a device/emulator with real seed data
- [X] T016 [P] Double-check the guardian message text (T008) against existing WhatsApp report emoji/wording conventions in `lib/views/settings/settings_page.dart` and `lib/views/students/student_details_page.dart` for consistency

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup (uses the constant from T001) — BLOCKS User Story 2 only (US1 does not touch the toggle).
- **User Story 1 (Phase 3)**: Depends only on Setup (T001). Fully independent of Phase 2/US2/US3 — can be built, tested, and shipped first.
- **User Story 2 (Phase 4)**: Depends on Foundational (T002) and is functionally meaningless without it (FR-006/FR-007 require the toggle to exist to gate on). Does not depend on User Story 1.
- **User Story 3 (Phase 5)**: Depends on Foundational (T002) only — adds the visible control for state that already exists after Phase 2. Can technically be built in parallel with US2, but should ship together with it (an invisible toggle with nothing to gate, or a gated action with no visible toggle, are both incomplete on their own).
- **Polish (Phase 6)**: Depends on all three user stories being complete.

### Parallel Opportunities

- T008 (message builder) can be built in parallel with T009/T010 (UI) since it's a pure function with no UI dependency, then wired together at T011.
- T014 and T016 in Polish can run in parallel with each other.
- User Story 3 (Phase 5) can be built in parallel with User Story 2 (Phase 4) by a second person, since both only depend on Phase 2, not on each other — but see note above about shipping them together.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (T001).
2. Complete Phase 3 (T003–T006) — User Story 1.
3. **STOP and VALIDATE**: run `quickstart.md` Scenario 1 independently.
4. This alone is shippable — the countdown has standalone value with zero WhatsApp/Settings work done yet.

### Incremental Delivery

1. Phase 1 → Phase 3 (US1) → validate → ship (MVP).
2. Phase 2 (T002) → Phase 4 (US2, toggle forced on for testing) → validate against `quickstart.md` Scenario 3.
3. Phase 5 (US3) → validate against `quickstart.md` Scenario 2 → ship US2+US3 together (a gated send action needs its visible on/off switch to be a complete, safe feature for real teachers).
4. Phase 6 polish → final `quickstart.md` full pass → done.
