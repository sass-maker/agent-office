# Runtime drivers

How Office OS employs agent software it did not write, what it guarantees, and
where the boundary sits between what a runtime says and what the organization
knows.

## The three evidence layers

These are deliberately separate, and only one of them is history.

| Layer | Lives in | Authoritative? | Example |
|---|---|---|---|
| Provider-native diagnostics | `RuntimeTurnResult.rawDiagnostics` | No | A runtime's own log line |
| Normalized runtime events | `RuntimeEvent`, per session | No | `turnStarted`, `assistantOutput` |
| Organization events | `journal.jsonl` | **Yes** | `employee-outcome.assigned` |

A runtime that wants to change the organization returns a
`ProposedOrganizationCommand`. The caller submits it through the command
boundary, where authority and idempotency are decided and an organization event
is appended. A runtime event never mutates organization state, and is rejected
outright if it claims a binding or session other than the one that produced it.

**Runtime events are not persisted.** They are evidence about a session, and a
session does not outlive the app. What survives is the organization event the
work produced and, for scheduled work, its run receipt. If a future need calls
for retaining diagnostics, that is a deliberate retention decision with its own
size and privacy questions — not a side effect of emitting them.

## Driver lifecycle

```
register → resolve(binding) → availability() → openSession() → run(turn)* → stop()
```

1. **Register.** A driver is added to the registry by kind. Nothing is
   auto-discovered; Office OS ships three — Demo, Local Codex, and Local Claude
   Code — and the tests add a fourth.
2. **Resolve.** A binding resolves to either a driver or an *unavailable
   shadow* naming why: not installed, older than the binding requires,
   misconfigured, or unhealthy.
3. **Availability.** Asked, never assumed. A driver that cannot work says so,
   and Office OS reports it instead of substituting a different runtime.
4. **Session.** Created per employee, binding, and session identifier. A session
   belongs to one employee and refuses another employee's turn.
5. **Turns.** Each turn returns output, normalized events, an optional resume
   cursor, and optional raw diagnostics.
6. **Stop.** Ends the session. Presence records it; a session still marked alive
   after a restart is stopped with a reason, because a process cannot outlive
   the app that hosted it.

## Compatibility

A driver declares a contract `version`. A binding records the version it was
created against.

- Driver version **≥** binding version → resolves.
- Driver version **<** binding version → incompatible, reported with both
  numbers. Office OS does not run a binding against an older contract and hope.

Optional facilities are negotiated through `declaredCapabilities` rather than
assumed. A driver that is not chat-based, not process-based, or not resumable is
still a first-class runtime.

## Event ordering

- Events from one session are emitted in the order the session produced them.
- Ordering across sessions is not defined and must not be relied on. Correlate
  with `correlationID` instead.
- Organization events are ordered by journal sequence, never by timestamp, so a
  clock change cannot reorder history.

## Configuration and secrets

`RuntimeConfigurationValue` is either a literal or a reference to a secret held
elsewhere. A driver declares which fields are secret, and validation rejects a
literal in one of those fields.

Nothing in the runtime layer reads a secret. Resolving a reference is a
deliberate owner handoff, and credential values never appear in runtime events,
organization events, or receipts — the permission broker redacts secret-shaped
content when a request is built, before anything is recorded.

## What a driver may not do

- Become the employee's identity. Rebinding changes the runtime, never the
  employee, its history, or its contract.
- Use a capability outside the intersection of runtime support, package
  boundaries, working contract, organization grant, commitment scope, and review
  policy.
- Turn its own suggestion into policy. A provider's "always allow" is recorded
  and ignored; widening authority is an owner action on the contract.
- Answer its own consequential question, accept its own delivery, or record its
  own permission decision.

## Failure isolation

One driver being missing, misconfigured, or unhealthy affects only the employees
bound to it. Employees on other drivers keep working. A lost runtime blocks the
affected commitment with a readable reason; it never retires the employee,
erases the commitment, or fabricates a delivery.

## Agent and model are separate choices

Which software does the work (**Agent**) and which model that software runs
(**Model**) are two decisions, and either can be left on Auto.

| Choice | Values | Auto means |
|---|---|---|
| Agent | Auto, Codex, Claude Code, Practice mode | Resolve at run time from what is healthy |
| Model | Auto, or a model the selected runtime supports | Send **no** override; the runtime's default applies |

Auto model sends no `--model` argument and records `modelName` as `nil` on the
receipt. Writing down whichever model happened to run would be a claim the app
cannot substantiate. A model can only be named once an agent is named, so Auto
and Practice mode offer no model choice at all.

## Finding a locally installed CLI

An app bundle launched from Finder, the Dock, or Spotlight inherits `launchd`'s
environment, not the owner's shell. Reading `PATH` alone therefore reports a
perfectly healthy CLI as missing.

`LocalAgentDiscovery` searches in a fixed order and stops at the first hit:

1. the `PATH` this process inherited,
2. the `PATH` the owner's **login shell** reports, recovered by running
   `$SHELL -l -i -c` once and caching the result,
3. directories the installers are known to use.

Only `PATH` is read. No credential, token, or configuration file is opened, and
the recovered environment is never logged or recorded. Recovery is bounded by a
timeout, so a start-up file that waits for input degrades to "nothing
recovered" rather than hanging the app.

## Asking a CLI which models it offers

The list of models is asked of the installed CLI rather than asserted by Office
OS. A hardcoded list ages into a lie: the names it carried before this contract
existed (`gpt-5.1-codex` and friends) are not in any catalogue Codex ships today.

| CLI | Listing command | Cost | Why |
|---|---|---|---|
| Codex | `codex debug models --bundled` | Free, offline | Renders the catalogue the installed binary already carries; `--bundled` skips the refresh, so nothing reaches the network |
| Claude Code | **none** | — | The CLI has no model-listing subcommand. `claude models` is not a command: the argument is forwarded to the model as a prompt, so asking would start a billed session |

A listing command must be free and offline. A probe that would open a session is
not a listing command, however much it reads like one.

### What the owner is shown

Every list carries where it came from, so an assumption can never be presented
as a report.

| Provenance | Names shown | Said on screen |
|---|---|---|
| `reportedByCLI` | What the CLI listed | "Codex reported these models on this Mac." |
| `assumed(reason:)` | Office OS's own list | "Office OS is showing what it assumes… not what … reported", plus why it cannot be asked |
| `unavailable(failure)` | **none** | The failure, in the owner's terms, and that Auto still works |

The rule behind the third row: **if the CLI could have been asked and the ask
failed, Office OS does not substitute a guess.** Falling back to a static list
there would make a failure look like a successful discovery — the same reason
`RunUsage` reports `unknown` rather than zero. A CLI with nothing to ask is the
only case where assuming is honest, and it says so.

Auto is always offered, so a runtime that cannot be asked is still fully usable:
its own default applies and nothing is claimed about which model ran. A model
name a contract already carries stays selectable even when the runtime did not
list it, so a failed ask cannot quietly reset an owner's choice.

### When the ask happens

- On demand, from the screen that shows a model choice — never at launch, and
  never while drawing a picker.
- Answers are remembered per CLI **and per executable path**, so an answer about
  a different binary is not reused for this one.
- A report stands for 6 hours; a failure for 60 seconds. One lifetime cannot do
  both: a long one pins a transient failure, a short one shells out constantly
  for an answer that only changes when the owner updates the CLI.
- "Check again" forgets the remembered answers along with the recovered `PATH`,
  because they describe the same installation.

Choosing the command and reading the answer are pure and unit-tested. Only
`SystemRuntimeModelListingRunner` touches a process; it closes standard input,
drains both streams concurrently, and abandons a command that overstays its
budget. The catalogue also carries prompt templates and other runtime internals,
which are never decoded, logged, or recorded — only the model names are kept.

## Auto-resolution policy

`RuntimeAutoResolver` applies these in order, and records which rule decided:

1. An explicit employee runtime choice is preserved — including its failure.
2. Otherwise the employee's last successful runtime, when healthy.
3. Otherwise the employee's package preference.
4. Otherwise healthy Codex, then healthy Claude Code.
5. The resolved driver and model are recorded on the session and the receipt.
6. A runtime is never switched during an active commitment.
7. Demo is never silently substituted.

Rules 1 and 6 are allowed to *block*. Falling through from a failed explicit
choice to a different runtime would be precisely the substitution this policy
exists to prevent.

### Why rule 7 cannot be violated

Rule 7 is enforced by the type system rather than by care. `AutoSelectableRuntime`
has exactly two cases, `codex` and `claudeCode`, and no case that denotes Demo.
Every automatic branch of the resolver builds its result from that type, so
there is no value it could return that means rehearsal. Demo is reachable only
through `SelectedRuntime.ownerChosen`, which requires the owner to have named
it, and `AutoSelectableRuntime(driverKind:)` returns `nil` for Demo so a kind
cannot be laundered into an automatic choice by passing it in.

Running out of real runtimes is therefore a refusal, not a rehearsal: an
employee blocks with a readable reason. A rehearsal presented as work is worse
than no work.

### Where the policy is applied

The resolver is a pure function, so something has to call it. Exactly one
production path does, through
`OrganizationState.resolveRuntime(for:health:commitmentID:)`:

- **`EmployeeOutcomeEngine.run`** resolves before any runner is invoked. A
  refusal leaves the commitment `waiting` with the reason as its help request
  and never calls the runner. On success it pins `runtimeKind`,
  `runtimeModelName`, and `runtimeSelectionRule` onto the commitment — this pin
  *is* rule 6, and once written it is never rewritten, so a later contract edit
  cannot move work that is already open.

`AppModel` probes the machine once (`runtimeHealth`) and hands the result down.
It also resolves *before* binding, and `bindResolvedRuntime` points the binding
at whatever resolution chose. Reading the binding first is what used to make
`Auto` mean "Codex, healthy or not".

Whether a run is real is a property of the resolved runtime, not of the
organization-wide `executionMode`. Web research is permitted only when
`ResolvedRuntimeSelection.isRehearsal` is false, so an employee whose contract
names a real runtime does real research even in an organization whose legacy
mode still says Practice.

Engines default `runtimeHealth` to `.practiceOnly`, which reports no real
runtime. That fails closed: a caller that forgets to probe gets a refusal, never
a silent rehearsal.

The persisted two-valued `executionMode` field is retired from current runtime
policy. It remains in the organization snapshot only so older files and older
app versions can decode one another. During legacy migration its value may be
copied into a missing employee contract; after that, execution, preflight,
routine projection, and onboarding read per-employee working contracts. If a
contract is unexpectedly absent, resolution uses Auto and fails closed rather
than consulting the legacy field or silently rehearsing.
