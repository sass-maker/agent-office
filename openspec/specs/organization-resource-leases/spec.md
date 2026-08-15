# organization-resource-leases Specification

## Purpose
Lets employees claim the things they are working on for a bounded time, so
concurrent work contends explicitly instead of overwriting each other quietly.
## Requirements
### Requirement: Leases cover typed organization resources
The system SHALL support leases over typed organization resources including
commitments, artifacts, records, connections, and shared workspaces, and SHALL
NOT assume repositories, branches, worktrees, or source files.

#### Scenario: Employee claims an artifact
- **WHEN** an employee acquires a lease over an artifact
- **THEN** the lease records the resource type and identifier, the holder, the access mode, the purpose, and when it expires

#### Scenario: Resource type is not file-shaped
- **WHEN** a lease is taken over a connection or a commitment
- **THEN** it behaves the same as any other resource lease

### Requirement: Shared reads coexist and exclusive writes do not
The system SHALL allow multiple shared-read leases over the same resource, and
SHALL refuse an exclusive lease while any other live lease exists over that
resource, reporting who holds it.

#### Scenario: Two employees read the same record
- **WHEN** two employees hold shared leases over one record
- **THEN** both succeed

#### Scenario: Exclusive claim meets a live lease
- **WHEN** an employee requests an exclusive lease over a resource someone else holds
- **THEN** the request is refused and names the current holder

#### Scenario: Shared claim meets an exclusive lease
- **WHEN** an employee requests a shared lease over a resource held exclusively
- **THEN** the request is refused and names the current holder

### Requirement: Leases expire by time, not by trust
A lease SHALL carry an expiry and SHALL stop blocking others once it passes.
Renewing SHALL extend it, releasing SHALL end it, and reconciliation SHALL mark
expired leases without deleting their history.

#### Scenario: Lease expires while its holder is gone
- **WHEN** a lease passes its expiry
- **THEN** another employee can acquire the resource, and the expired lease remains inspectable

#### Scenario: Holder renews before expiry
- **WHEN** a holder renews a live lease
- **THEN** its expiry moves and no one else can take the resource

#### Scenario: Holder releases early
- **WHEN** a holder releases a lease
- **THEN** the resource is immediately available and the release is recorded

### Requirement: Contention is a decision, not an error
The system SHALL expose current holders, expired leases, and conflicts so the
owner or an employee can decide what to do, and SHALL NOT preempt a live lease
automatically.

#### Scenario: Owner inspects contention
- **WHEN** a resource is contended
- **THEN** the current holder, purpose, and expiry are readable

#### Scenario: A live lease is never taken by force
- **WHEN** a second employee wants a resource that is legitimately held
- **THEN** nothing is preempted and the refusal explains who holds it and until when

