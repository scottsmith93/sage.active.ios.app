# Sage Active iOS prototype

## Purpose

This repository contains a native iOS research prototype. It is not production software and must not be described as legally or tax compliant.

## Collaborator context

The project owner is an experienced product designer learning native development. Explain unfamiliar Swift, SwiftUI, Xcode, testing, and source-control concepts in plain language.

## Product rules

- Use native SwiftUI components and native navigation wherever practical.
- Keep Overview focused on current position and immediate actions.
- Keep Insights focused on historical business performance.
- Keep cash-flow forecasts behind the bank-balance route.
- Treat bank balances and cash movements as IVA-inclusive cash values.
- Keep bank balances IVA-inclusive; allow invoice and analytical values to respond to the IVA preference.
- Use Apple semantic colours for page and card surfaces until company tokens are supplied.
- Keep Insights months chronological from left to right and initially centre the current month.
- Bank-account selection changes the forecast starting balance; invoice movements remain business-wide until account allocation exists in the dataset.
- Use Spanish regional currency formatting.
- Use fictional data only.

## Interaction and accessibility rules

- Do not rely on colour alone to communicate direction or urgency.
- Give icon-only controls meaningful accessibility labels.
- Preserve Dynamic Type and VoiceOver behaviour.
- Keep essential values available without chart gestures.
- Use native Back navigation and pull-to-refresh.
- Do not show chevrons for destinations that do not exist.

## Engineering rules

- Keep the architecture small and feature-oriented.
- Do not add third-party dependencies without approval.
- Keep mock-data loading behind a data-source boundary so it can be replaced later.
- Store money as integer cents.
- Keep calculations out of SwiftUI view bodies when they can be tested independently.
- Build after meaningful changes and run the narrowest relevant checks.
- Report what was verified and what was not.
