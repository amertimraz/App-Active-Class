# Phase 0 Research: Session Countdown & Post-Attendance WhatsApp Report

## 1. How to determine "is a group's session live right now"

**Decision**: Reuse and extend the existing `AttendanceController.sessionTimeForGroupOnDay(Group, DateTime)` / `groupHasSessionOnDay` helpers in `lib/controllers/attendance_controller.dart`. These already parse `Group.schedule` (a free-text string like `"الاثنين 5:00 م, الأربعاء 5:00 م"`) into a per-weekday start time. Add a sibling helper, e.g. `sessionWindowForGroupNow(Group, DateTime now)`, that:
1. Resolves today's start time the same way `sessionTimeForGroupOnDay` does.
2. Computes an end time = start + a default session length (see §2) unless a future schema change adds an explicit duration.
3. Returns `null` if `now` is outside `[start, end)`, or a remaining `Duration` if inside.

**Rationale**: `Group.schedule` already exists and is the only source of truth for weekly timing (confirmed in spec Assumptions). Reusing the existing parser avoids a second, divergent implementation of the same weekday/time parsing logic that already handles the app's Arabic weekday-name format.

**Alternatives considered**:
- Adding a structured `sessionDurationMinutes` field to `Group` — rejected for this feature; it's a schema change with migration cost, and the spec's default-length fallback (§2) is sufficient for v1. Left as a natural follow-up if teachers want per-group custom durations later.

## 2. Default session length fallback

**Decision**: 60 minutes, configurable as a single constant (`DEFAULT_SESSION_MINUTES` in `lib/config/constants.dart`), used whenever a group's schedule entry has no explicit end/duration (i.e., always, until/unless a future feature adds one).

**Rationale**: 60 minutes is a reasonable default for a private-tutoring session and matches this domain (the existing exam/homework features already assume single-session granularity). Keeping it as one named constant (not hardcoded inline) makes it trivial to change later without hunting through UI code, and is consistent with how other domain constants (e.g., `HOMEWORK_DONE`) are centralized in this codebase.

**Alternatives considered**:
- Per-group custom duration — deferred (see §1 alternatives); not required by any acceptance scenario in spec.md.
- No countdown when only a start time exists — rejected; this would mean the countdown almost never shows, since no group in the existing data model currently stores an explicit end time, defeating User Story 1 entirely.

## 3. Deriving "attendance is complete for this group today"

**Decision**: Compute inline where attendance is already loaded (`AttendanceController.attendance`, already an `RxList` kept in sync — see `attendance_page.dart`'s existing `_RegisterTab` Obx block): a group's attendance is "complete for today" when every student currently in that group has at least one attendance record (present or absent) whose date falls on today. This is a pure derived boolean, not a new stored field — recomputed reactively the same way `presentCount`/`absentCount` are already computed per group card today.

**Rationale**: This matches the existing reactive pattern in `_GroupAttendanceCard` exactly (student roster × today's `statusMap` lookup) and requires no new database table or column — attendance completion is just "roster size == today's marked count" for that group, derived on every rebuild like the rest of the card's stats already are.

**Alternatives considered**:
- A persisted "report sent" flag per group per day — considered for the edge case (spec Edge Cases: teacher edits attendance after the report was already sent). Deferred to implementation-time judgment in tasks.md rather than a Phase 0 decision, since it only affects a secondary edge case, not the core flow.

## 4. WhatsApp send mechanism

**Decision**: Reuse the exact pattern already implemented in `lib/views/settings/settings_page.dart`'s `_startWhatsappBatchSend`/`_publishAll`-style flow: build a per-guardian message string, construct a `https://wa.me/{phone}?text={encoded}` URI, `launchUrl(..., mode: LaunchMode.externalApplication)`, then wait for the app to resume (existing `_waitForResume()` / `WidgetsBindingObserver` helper) before moving to the next guardian. No new package, no server component.

**Rationale**: This is a proven, already-shipped pattern in this exact codebase (used today for the monthly WhatsApp report). Reusing it keeps the UX consistent (teacher already knows this flow from the existing batch-send feature) and avoids introducing WhatsApp Business API scope, cost, and verification requirements that are explicitly out of scope per spec.md Assumptions.

**Alternatives considered**:
- WhatsApp Business API (Meta Cloud API) for true silent bulk send — rejected, out of scope per spec Assumptions (paid, requires business verification, not justified for this feature).

## 5. Message content format

**Decision**: One message per guardian, plain text (matching the existing report style used elsewhere in this app, e.g. `student_details_page.dart`'s monthly report), containing: student name, today's date, attendance status (✅ حاضر / ❌ غائب), and homework status for today (📗 عمل / 📙 لم يعمل / "لم يُسجَّل" if no homework record exists for today). Reuses `FormatHelper`/existing emoji conventions already used across the app's WhatsApp/report text (see `settings_page.dart`, `student_details_page.dart`).

**Rationale**: Consistency with every other guardian-facing message this app already sends; no new formatting convention to design or for the teacher to learn.

**Alternatives considered**: None warranted — this directly follows FR-010 and existing precedent.

## 6. Countdown UI refresh mechanism

**Decision**: A `Timer.periodic` (e.g., every 30–60 seconds — sub-minute precision is not required for a countdown measured in minutes) owned by the attendance page's existing state, driving a `setState`/`Obx` update of only the countdown text, not the whole list. Timer is disposed with the page (existing `dispose()` pattern already used for other timers/observers in this codebase, e.g. `_statsTimer` in `exam_grades_page.dart`).

**Rationale**: Matches the debounce/timer pattern already established and reviewed this session (`exam_grades_page.dart`'s `_scheduleStatsRefresh`), so it is a known-safe pattern in this codebase (proper cancellation in `dispose()`, no leaked timers).

**Alternatives considered**:
- A `Stream.periodic` — unnecessary complexity for a simple periodic UI tick; `Timer.periodic` is simpler and is the existing convention in this codebase.

## Outstanding items for `/speckit-tasks`

None blocking — all Phase 0 unknowns are resolved above. One judgment call is explicitly deferred to task-breakdown time: whether to add a "report already sent today" guard (§3 Alternatives) to address the edge case in spec.md ("teacher edits attendance after sending") — recommend including it as a low-cost addition (a per-group-per-day boolean, session-memory only, not persisted) since it directly prevents the edge case without new storage.
