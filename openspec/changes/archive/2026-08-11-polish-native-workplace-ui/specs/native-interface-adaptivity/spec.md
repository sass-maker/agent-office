## Purpose

Defines how the native workplace remains composed, readable, and recognizably Editorial Office across supported macOS window sizes and system appearances.

## ADDED Requirements

### Requirement: Primary windows resize structurally
The application SHALL support compact, intermediate, and wide macOS window sizes by changing layout topology rather than shrinking functional text or clipping primary actions.

#### Scenario: Owner resizes the main window
- **WHEN** the main window moves between its supported minimum width and a wide desktop width
- **THEN** navigation, content, and contextual detail reorganize without horizontal clipping or inaccessible actions

#### Scenario: Owner resizes a supporting sheet
- **WHEN** a catalogue, assignment, research, or contract sheet is presented in a compact host window
- **THEN** the sheet remains scrollable and usable without requiring a width larger than the host window

### Requirement: Editorial Office supports both system appearances
The application SHALL provide authored light and dark appearances that preserve paper, ink, rule, typography, and hierarchy roles without encoding status through hue alone.

#### Scenario: System appearance changes
- **WHEN** macOS changes between light and dark appearance
- **THEN** every primary destination and onboarding updates without relaunching
- **AND** text, controls, focus, and separators remain legible

#### Scenario: Dark appearance is active
- **WHEN** the workplace is shown in dark appearance
- **THEN** large reading surfaces use warm charcoal and muted parchment roles rather than pure black, pure white, or a mechanical color inversion

### Requirement: Accessibility preferences remain authoritative
The adaptive interface MUST preserve Dynamic Type, keyboard access, VoiceOver labels, visible focus, and Reduce Motion behavior in every supported size and appearance.

#### Scenario: Owner uses accessibility settings at a compact width
- **WHEN** the owner increases text size, navigates by keyboard, or enables Reduce Motion while the window is narrow
- **THEN** primary destinations and consequential actions remain reachable and understandable

