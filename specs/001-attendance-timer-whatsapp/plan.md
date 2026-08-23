# Implementation Plan: Session Countdown & Post-Attendance WhatsApp Report

**Branch**: `001-attendance-timer-whatsapp` | **Date**: 2026-08-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-attendance-timer-whatsapp/spec.md`

## Summary

Two additions to the existing attendance screen: (1) a live countdown shown inline on each group's card in the daily attendance list, visible only while that group's scheduled session is currently running; (2) once every enrolled student in a group has an attendance mark for today, a "send WhatsApp report" action becomes available that — after the teacher reviews and confirms a recipient summary — opens one WhatsApp chat per guardian (all enrolled students, present or absent) pre-filled with that student's today's attendance + homework status. Feature (2) is gated by a new Settings toggle, defaulted off. Both features reuse existing schedule-parsing, attendance/homework data, and WhatsApp-launch patterns already present in the codebase rather than introducing new dependencies.

## Technical Context

**Language/Version**: Dart (Flutter, existing app — SDK constraint already pinned in `pubspec.yaml`)

**Primary Dependencies**: `get` (GetX state management, already used app-wide), `url_launcher` (already used for `wa.me` deep links in `settings_page.dart` and `student_details_page.dart`), `intl` (date formatting), no new packages required

**Storage**: SQLite via `sqflite` (`DatabaseService`) — reads existing `attendance`, `homework`, `students`, `groups` tables; one new key in the existing `app_settings` key/value table for the toggle (same mechanism as every other Settings toggle in this app, e.g. `whatsappEnabled`)

**Testing**: This project has no automated test suite; verification is `flutter analyze` (zero errors/warnings gate) plus manual verification against a running build, consistent with how every other feature in this codebase has been validated

**Target Platform**: Android (existing app; release channel is APK + AAB via `flutter build`)

**Project Type**: Mobile app (single Flutter project, existing `lib/` structure — not a new project type)

**Performance Goals**: Countdown must visibly tick without noticeable jank on a low-end Android device; no additional network calls introduced (WhatsApp send reuses the existing `wa.me` link-per-guardian pattern, which is inherently rate-limited by requiring the teacher to return to the app between each)

**Constraints**: No WhatsApp Business API / server-side messaging is available or in scope (confirmed in spec Assumptions) — "send" means opening `wa.me` links one at a time via `url_launcher`, same as the existing bulk-send flow in `settings_page.dart`; must not send anything without the explicit confirm step (FR-012); toggle must default to off for all existing and new installs (FR-008)

**Scale/Scope**: Two additions to one existing screen (`lib/views/attendance/attendance_page.dart`) plus one new toggle row in `lib/views/settings/settings_page.dart`; no new screens

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the unfilled template for this project (no ratified principles yet — `/speckit-constitution` has not been run). No project-specific gates exist to evaluate against. Treating this as **PASS (no gates defined)**; falling back to this codebase's established conventions (documented in Technical Context above and research.md) in place of formal constitution gates.

**Post-Phase-1 re-check**: PASS (unchanged) — the Phase 1 design (data-model.md, quickstart.md) introduces no new dependency, no new storage beyond one settings key, and no deviation from existing app conventions; there is nothing for a future constitution to flag. `contracts/` was intentionally skipped — this feature exposes no external API/interface beyond the already-documented `wa.me` URI pattern (research.md §4–5), consistent with the "skip if purely internal" guidance for this artifact.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── controllers/
│   ├── attendance_controller.dart      # add: session-window lookup, countdown ticker source
│   ├── homework_controller.dart        # existing — read for today's homework status
│   └── settings_controller.dart        # add: reportOnCompletionEnabled RxBool + persistence
├── views/
│   ├── attendance/
│   │   └── attendance_page.dart        # add: countdown chip on _GroupAttendanceCard,
│   │                                    #      "send report" action + confirm sheet
│   └── settings/
│       └── settings_page.dart          # add: one new toggle row (existing pattern)
├── services/
│   └── database_service.dart           # existing getters reused; no schema change needed
└── config/
    └── constants.dart                  # add: setting key constant + default session length
```

**Structure Decision**: Single existing Flutter project (`lib/`) — no new module, package, or directory. This feature is additive UI/state on top of two already-existing screens and reuses `DatabaseService`/`AttendanceController`/`HomeworkController`/`SettingsController` exactly as every prior feature in this codebase (homework tracking, exam grades, parent portal) has done. No `tests/` directory changes — this project has none; validation follows `quickstart.md`.

## Complexity Tracking

Not applicable — no constitution gates were violated (no gates are currently defined for this project).
