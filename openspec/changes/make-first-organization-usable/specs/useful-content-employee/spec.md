## Purpose

Let the first hired content employee turn a real product brief into a reviewed, evidence-aware article and a concise owner handoff in one bounded workday.

## ADDED Requirements

### Requirement: Content work begins from real product context
The system SHALL let the owner provide and later edit a product brief containing enough context to identify the product, audience, problem, and current claims, and SHALL pass that brief to the content employee's work.

#### Scenario: Product brief is missing
- **WHEN** the owner starts a real content workday without a meaningful product brief
- **THEN** the employee stops before research and surfaces a precise request for the missing context

#### Scenario: Product brief is present
- **WHEN** the owner starts a workday with a meaningful product brief
- **THEN** research and drafting use the brief and preserve it as attributable source context

### Requirement: Content manager owns a bounded outcome
The content manager SHALL turn the organization outcome into research, drafting, review, and owner-report work, delegating to assigned specialists where present, with no more than the configured maximum revision count.

#### Scenario: Article is approved
- **WHEN** research and a draft satisfy the manager's review
- **THEN** the system stores the approved article, evidence notes, review, and owner report as ordinary local artifacts and marks the outcome complete

#### Scenario: Revision limit is reached
- **WHEN** the draft still fails review after the maximum revision count
- **THEN** the cycle stops, records the unresolved review as a blocker, and asks the owner for judgment instead of starting another cycle

### Requirement: Useful output carries provenance
The final article and owner report SHALL identify the product brief, research evidence, contributing employees, review result, and creation workday without presenting unsupported claims as researched facts.

#### Scenario: External research is unavailable
- **WHEN** web research is not granted or the local runtime cannot perform it
- **THEN** the employee labels the article as based only on owner-provided context and does not fabricate external sources

#### Scenario: External research succeeds
- **WHEN** permitted web research returns source material
- **THEN** the evidence artifact includes source URLs or titles and the article distinguishes sourced evidence from product claims supplied by the owner

