# Quickstart: Session Countdown & Post-Attendance WhatsApp Report

Manual end-to-end validation guide (this project has no automated test suite — see plan.md Technical Context). Run these after `/speckit-implement` completes, against a debug or release build on a real Android device or emulator with existing seed data (at least one group with a `schedule` entry and enrolled students that have `guardianPhone` set).

## Prerequisites

- A group whose `schedule` includes today's weekday.
- At least 2 students enrolled in that group; at least one with a `guardianPhone` set, one without (to exercise the skip path).
- WhatsApp installed on the test device (or accept that the `wa.me` link will prompt an app chooser / browser fallback if not).

## Scenario 1 — Countdown appears and updates (User Story 1)

1. Set the device clock (or pick a group's schedule time) so "now" falls inside a group's session window.
2. Open the attendance screen (`lib/views/attendance/attendance_page.dart`).
3. **Expect**: that group's card shows a countdown of remaining time, inline in the list (per spec Q3/FR-002).
4. Wait ~1 minute without leaving the screen.
5. **Expect**: the countdown value decreases without a manual refresh.
6. Advance time past the session's computed end (start + `DEFAULT_SESSION_MINUTES`).
7. **Expect**: the countdown disappears for that group (FR-003).
8. Repeat for a group with no schedule entry, or where "now" is outside every group's window.
9. **Expect**: no countdown shown (Acceptance Scenario 3).

## Scenario 2 — Send action only appears when attendance is complete (User Stories 2 & 3)

1. In Settings, confirm the new toggle is **off** by default on a fresh install (FR-008).
2. With the toggle off, mark attendance for every student in a group.
3. **Expect**: no "send WhatsApp report" action appears anywhere for that group (FR-007).
4. Turn the toggle on in Settings.
5. Mark attendance for only some students in a group (leave at least one unmarked).
6. **Expect**: the send action is not available/is disabled (Acceptance Scenario 2).
7. Mark the remaining student(s).
8. **Expect**: the send action becomes available immediately once the last student is marked (Acceptance Scenario 1).

## Scenario 3 — Confirm-then-send flow and message content (FR-010–FR-013)

1. With a group's attendance fully marked and the toggle on, trigger the send action.
2. **Expect**: a summary screen/dialog lists every recipient guardian before anything is sent, and requires explicit confirmation (FR-012, Clarifications Q1 = A).
3. **Expect**: the summary/skip count reflects any student with no `guardianPhone` (FR-011).
4. Confirm the send.
5. **Expect**: one `wa.me` link opens per guardian with a phone on file, for both present and absent students (FR-013, Clarifications Q2 = A) — verify by checking the pre-filled WhatsApp message text before actually sending it.
6. **Expect**: each pre-filled message contains the student's name, today's date, today's attendance status, and today's homework status (showing "لم يُسجَّل" for a student with no homework record for today).
7. Turn the Settings toggle off again.
8. **Expect**: the send action no longer appears for any group, even one already fully marked (Acceptance Scenario 3 of User Story 3).

## Regression checks

- `flutter analyze` reports zero new errors/warnings introduced by this feature (existing project convention — see plan.md Technical Context).
- Existing attendance-marking flows (mark present/absent, mark-all-present, homework toggle) still work unchanged on a group card that now also shows a countdown and/or send action.
- Existing Settings toggles (e.g. `whatsappEnabled`) are unaffected by the new toggle's addition.
