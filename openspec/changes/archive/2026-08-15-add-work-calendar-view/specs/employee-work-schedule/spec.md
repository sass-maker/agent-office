## ADDED Requirements

### Requirement: Scheduled work is visible as a temporal projection
The system SHALL offer day and week views derived from schedule policies,
occurrences, and receipts, showing expected and actual work distinctly. Each
block SHALL expose its employee, subject, status, planned window, actual run
where one exists, and its receipt headline where one exists. The view SHALL be a
projection: it SHALL NOT create work, and SHALL show nothing where no policy
produced an occurrence.

#### Scenario: A week with scheduled and completed work
- **WHEN** the owner opens the week view
- **THEN** each occurrence appears on its scheduled day with its status, and completed ones show what actually ran

#### Scenario: No schedules exist
- **WHEN** no schedule policy exists
- **THEN** the view says so plainly rather than showing invented blocks

#### Scenario: Status is legible without colour
- **WHEN** an occurrence is missed, quiet, or delivered
- **THEN** its state is conveyed in text, not by colour alone

### Requirement: Missed windows follow an owner-authored catch-up policy
Each schedule policy SHALL declare what happens to a window that passes
unexecuted: leave it missed, or reschedule it into the next window.
Reconciliation SHALL apply that decision deterministically and SHALL NOT execute
anything late.

#### Scenario: Policy leaves missed windows missed
- **WHEN** a window passes unexecuted under the leave-missed policy
- **THEN** the occurrence is missed and no replacement is created

#### Scenario: Policy reschedules into the next window
- **WHEN** a window passes unexecuted under the reschedule policy
- **THEN** the occurrence is missed, one replacement occurrence is created for the next window, and nothing runs

#### Scenario: Reconciliation repeats
- **WHEN** reconciliation runs again after rescheduling
- **THEN** no further replacement is created
