# Phase 1 Data Model: Session Countdown & Post-Attendance WhatsApp Report

No new database tables or columns are introduced by this feature. Everything below is either an in-memory derived value, computed on the fly from existing tables (`groups`, `students`, `attendance`, `homework`), or a single new key/value setting reusing the existing settings mechanism.

## Existing entities reused (no changes)

- **Group** (`lib/models/group_model.dart`) — `schedule` (free-text weekly day/time string) is the sole input to the session-window calculation. No fields added.
- **Student** (`lib/models/student_model.dart`) — `groupId`, `guardianPhone` used to determine the report's recipient list. No fields added.
- **Attendance** (`lib/models/attendance_model.dart`) — `studentId`, `date`, `status` (present/absent) used both for today's completion check and for the report content. No fields added.
- **Homework** (`lib/models/homework_model.dart`) — `studentId`, `date`, `status` used for the report's homework line. No fields added.

## New derived (in-memory only) concepts

### SessionWindow

Not a stored entity — a pure function result.

| Field | Type | Source |
|---|---|---|
| `groupId` | int | input |
| `start` | DateTime | parsed from `Group.schedule` for today's weekday (existing parser) |
| `end` | DateTime | `start + Duration(minutes: DEFAULT_SESSION_MINUTES)` |
| `remaining` | Duration? | `end - now`, `null` if `now` is outside `[start, end)` |

Computed on demand (e.g., every countdown tick); never persisted.

### GroupAttendanceCompletion

Not a stored entity — a pure derived boolean per group per day, computed the same way existing per-card stats (`presentCount`/`absentCount`) already are.

| Field | Type | Source |
|---|---|---|
| `groupId` | int | input |
| `date` | DateTime (day-only) | input (today) |
| `enrolledStudentIds` | Set\<int\> | `students.where(groupId)` |
| `markedStudentIds` | Set\<int\> | `attendance.where(groupId's students AND date == today)` distinct `studentId` |
| `isComplete` | bool | `enrolledStudentIds == markedStudentIds` (every enrolled student has a mark) |

### GuardianReportEntry (per recipient, built only when the send flow runs)

| Field | Type | Source |
|---|---|---|
| `studentId` | int | enrolled student |
| `studentName` | String | `Student.name` |
| `guardianPhone` | String? | `Student.guardianPhone` — entry is skipped from sending if null/empty (FR-011) |
| `attendanceStatus` | String | today's `Attendance.status` for this student (present/absent) — always present by construction, since the send action only appears when `GroupAttendanceCompletion.isComplete` |
| `homeworkStatus` | String? | today's `Homework.status` for this student, or `null` → rendered as "لم يُسجَّل" (not recorded) |

Not persisted — built once per send-flow invocation, discarded after the confirm/send step completes.

## New setting (reuses existing key/value settings mechanism)

| Key | Type | Default | Owner |
|---|---|---|---|
| `attendance_report_on_completion_enabled` | bool (stored as existing app's string-encoded setting convention) | `false` (FR-008) | `SettingsController` — new `RxBool reportOnCompletionEnabled`, read/written via the same `_dbService.getSetting`/`setSetting` pattern already used for every other toggle (e.g. `whatsappEnabled`) |

No migration required — this follows the existing `app_settings` key/value table pattern, which needs no schema change to add a new key.

## Validation / invariants carried over from spec.md

- The send action (and thus `GuardianReportEntry` construction) must never be offered unless `GroupAttendanceCompletion.isComplete` is true for that group/day (FR-006).
- The send action must never be offered anywhere while `reportOnCompletionEnabled` is false (FR-007).
- Students with no `guardianPhone` are excluded from the recipient list and counted in a "skipped" summary shown to the teacher (FR-011).
