## Decisions

### One payload for the family, not one per verb

Approving a plan and accepting a delivery differ in what they do, not in who may
do them or what they are about. A single `superviseCommitment` payload keeps the
authority rule in one place and keeps the payload enum from growing a case per
UI button.

### Identifiers derived, not generated

The supervision event, activity entry, management message, and revision record
written by a decision now derive their identifiers from the commitment, the kind
of record, and the timestamp. Replay reproduces them exactly. This is the same
rule the assignment command already follows, and the replay test is what caught
the last random identifier.
