# Feature Specification: Session Countdown & Post-Attendance WhatsApp Report

**Feature Branch**: `001-attendance-timer-whatsapp`

**Created**: 2026-08-23

**Status**: Draft

**Input**: User description: "ميزتين مرتبطتين بشاشة تسجيل الحضور: (1) عداد تنازلي للحصة الحالية يوضح الوقت المتبقي لها بناءً على جدول المجموعة. (2) بعد ما المدرس يسجّل حضور كل طلاب المجموعة، زرار لإرسال رسالة واتساب لكل ولي أمر فيها حالة الحضور والواجب بتاع اليوم. الميزة التانية دي لازم تتفعّل/تتعطّل من شاشة الإعدادات، وافتراضيًا معطلة."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See how much time is left in the current session (Priority: P1)

While a teacher is in the middle of teaching a scheduled session and has the attendance screen open, they can see at a glance how much time remains before the session's scheduled end time, without needing to check a separate clock or their own calendar.

**Why this priority**: This is the simpler of the two capabilities, has no dependency on the WhatsApp feature, and delivers standalone value the moment it ships — teachers currently have no in-app sense of session pacing.

**Independent Test**: Open the attendance screen while a group's scheduled session window is currently active; confirm a countdown showing time remaining is visible on that group's card, and confirm it disappears (or shows a different state) once the session's scheduled end time passes.

**Acceptance Scenarios**:

1. **Given** a group has a weekly schedule entry for today with a start and end time, and the current time falls within that window, **When** the teacher opens the attendance screen, **Then** that group's card shows a live countdown of time remaining until the scheduled end time.
2. **Given** the countdown is visible and showing 5 minutes remaining, **When** 5 minutes pass without the teacher leaving the screen, **Then** the countdown updates to show the session has ended (or reaches zero) without requiring the teacher to refresh the screen manually.
3. **Given** a group has no session scheduled for right now (either no schedule is set, or the current time falls outside every group's scheduled windows), **When** the teacher opens the attendance screen, **Then** no countdown is shown for that group.
4. **Given** a group's schedule only specifies a start time with no explicit duration/end time [see Assumptions], **When** the current time is at or after that start time, **Then** the system falls back to the default session length to compute the countdown.

---

### User Story 2 - Notify guardians right after finishing attendance (Priority: P2)

Once a teacher has recorded attendance for every student in a group's session, they can trigger sending each guardian a status update covering that student's attendance and homework status for the day, without composing each message by hand.

**Why this priority**: This delivers the main "communicate with parents" value the request is about, but depends on attendance data being complete for the group and is naturally built after the countdown groundwork, so it is P2.

**Independent Test**: With the setting enabled, mark attendance for every student in a group for today; confirm the send action becomes available only once the last student is marked, and confirm triggering it produces one message per guardian containing that student's attendance and homework status for today.

**Acceptance Scenarios**:

1. **Given** the setting for this feature is enabled, and a teacher has marked attendance (present or absent) for every student in a group for today, **When** the teacher views that group's attendance card, **Then** a "send WhatsApp report" action is available for that group.
2. **Given** attendance is still missing for at least one student in the group, **When** the teacher views that group's attendance card, **Then** the send action is not available (or is disabled) for that group.
3. **Given** the teacher triggers the send action, **When** the send flow runs, **Then** the teacher is shown a summary of which guardians will receive a message before anything is sent, and must explicitly confirm before any message goes out.
4. **Given** a message is generated for a guardian, **When** the teacher reviews it, **Then** it includes the student's name, today's attendance status (present/absent), and today's homework status (done/not done/not applicable).
5. **Given** a student has no guardian phone number on file, **When** the send flow runs for that group, **Then** that student is skipped and the teacher is told how many students were skipped and why.

---

### User Story 3 - Turn the automatic-report feature on or off (Priority: P3)

A teacher who does not want to be prompted to message guardians after every session can leave the feature off; a teacher who wants it can turn it on from Settings, and it stays off by default so no teacher is surprised by it.

**Why this priority**: This is a small control surface that gates User Story 2; it only has meaning once Story 2 exists, so it is sequenced last even though it is simple to build.

**Independent Test**: With the setting off, confirm the send action from Story 2 never appears anywhere in the app. Turn the setting on from Settings, confirm the send action now appears once attendance is complete for a group.

**Acceptance Scenarios**:

1. **Given** a teacher has never touched this setting, **When** they finish marking attendance for a full group, **Then** no send action appears (the feature defaults to off).
2. **Given** the teacher opens Settings, **When** they turn the toggle on, **Then** the send action starts appearing after attendance is completed for any group from that point on.
3. **Given** the teacher turns the toggle back off, **When** they finish marking attendance for a group afterward, **Then** the send action no longer appears.

---

### Edge Cases

- What happens if the teacher edits an already-"complete" group's attendance afterward (e.g., corrects one student from absent to present)? Does the send action reappear/reset, given the report would now be based on stale data if already sent once?
- What happens if two of a group's scheduled sessions overlap in time due to a scheduling data-entry mistake? The countdown should not crash or show conflicting values — it should show the countdown for whichever session is found first.
- What happens if the teacher has homework tracking data for a different day than today for a student (e.g., they forgot to mark today's homework)? The report should reflect "not recorded" rather than showing stale data from a previous day.
- What happens if the device has no WhatsApp installed, or no internet connection, when the send action is triggered?
- What happens for a per-session-priced group where "today's session" doesn't map to a fixed weekly time slot in the same way? [see Assumptions]

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST determine, for each group with a schedule entry, whether the current time falls within that group's scheduled session window for today.
- **FR-002**: System MUST display a live, auto-updating countdown of remaining time inline on the attendance card of any group currently in its scheduled session window, within the same list view the teacher already uses to see today's groups (no separate screen needed to see it).
- **FR-003**: System MUST hide the countdown for a group once the current time is outside that group's scheduled session window (before start, or after the computed end).
- **FR-004**: System MUST treat a schedule entry that has no explicit end time as running for a default session length [see Assumptions] from its start time.
- **FR-005**: System MUST track, per group per day, whether every enrolled student currently has an attendance status (present or absent) recorded for that day.
- **FR-006**: System MUST offer a guardian-report send action for a group only when both (a) the Settings toggle for this feature is on, and (b) every enrolled student in that group has an attendance status recorded for today.
- **FR-007**: System MUST NOT offer the send action anywhere while the Settings toggle is off.
- **FR-008**: System MUST default the Settings toggle to off for every teacher until they explicitly turn it on.
- **FR-009**: System MUST persist the teacher's toggle choice so it survives closing and reopening the app.
- **FR-010**: When the send action is triggered, system MUST generate one message per student who has a guardian phone number on file, containing that student's name, today's attendance status, and today's homework status.
- **FR-011**: System MUST skip students with no guardian phone number on file and report to the teacher how many were skipped.
- **FR-012**: System MUST show the teacher a summary of recipients before messages are dispatched, and require the teacher's explicit confirmation before any message is sent — no fully-automatic, confirmation-free sending.
- **FR-013**: System MUST send the guardian report to every enrolled student's guardian in the group who has a phone on file, regardless of whether that student was marked present or absent today — an absent student's guardian receives an absence notice as part of this report.

### Key Entities

- **Session Window**: A group's scheduled day-of-week, start time, and (optionally) duration/end time; used to determine whether "now" falls inside a live session for that group.
- **Daily Attendance Completion State**: A derived state, per group per day, of whether every enrolled student has an attendance record for that day — drives whether the send action is available.
- **Guardian Report Message**: The per-student message content (attendance status + homework status for the day) generated and sent to that student's guardian.
- **Feature Setting**: A single per-teacher on/off preference controlling whether the guardian-report send action is ever offered.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A teacher looking at the attendance screen during a live session can tell how much time is left without leaving the app or checking another clock.
- **SC-002**: A teacher can notify every reachable guardian in a group about today's attendance and homework in under 1 minute of finishing attendance-taking, instead of messaging each guardian individually by hand.
- **SC-003**: No teacher receives the send action unless they explicitly opted in from Settings.
- **SC-004**: Zero reports are sent using stale or partial attendance data — the send action is only ever available once a group's attendance is fully recorded for the day.

## Assumptions

- A "default session length" (e.g., 60 minutes) is used when a group's schedule specifies only a start time with no explicit duration; the exact default value is a planning-time decision, not a spec-time one.
- The existing weekly schedule text already associated with each group is the source of truth for computing session windows; no new schedule-editing UI is in scope for this feature.
- For per-session-priced groups without a fixed recurring weekly slot, "today's session" is determined the same way today's attendance-eligible groups are already determined elsewhere in the app.
- Sending relies on the guardian's phone number already stored on the student record; no new contact-collection flow is in scope.
- Consistent with how this app already sends WhatsApp messages elsewhere, each guardian message is expected to require the teacher to confirm/tap send inside WhatsApp itself (no silent, fully-automated bulk delivery without WhatsApp's own send step) — true silent bulk sending would require a paid WhatsApp Business API integration, which is out of scope.
- "Today's homework status" reflects whichever homework record exists for that student for today's date; if none exists, the report shows it as not recorded rather than blank or misleading.

## Clarifications

### Session 2026-08-23

- **Q1: Confirm-before-send vs. fully automatic** → **A — Always require the teacher to review a recipient summary and explicitly confirm before any message is sent.** Encoded in FR-012 and User Story 2 Acceptance Scenario 3.
- **Q2: Who receives the report — all students, or only those marked present?** → **A — All enrolled students with a guardian phone on file, present and absent alike.** Encoded in FR-013.
- **Q3: Scope of the countdown display** → **A — Inline on each group's card in the existing attendance list view** (not a separate banner/screen). Encoded in FR-002.
