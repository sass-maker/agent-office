## Decisions

### Employment is its own payload

Employment decisions change *who works here*; supervision decisions change what a
hired employee is doing. Keeping them separate means the authority rule and the
entity references stay obvious, and neither payload grows a case that does not
belong to it.

### Hire returns what it produced

Hiring creates an identity, so the command result carries the new employee
identifier the way an assignment carries its commitment identifier. The app uses
it to select the new employee, rather than guessing from state afterwards.
