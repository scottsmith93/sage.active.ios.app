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
- Bank-account selection changes both the forecast starting balance and the invoice movements assigned to those accounts.
- Keep the app and widget responsive to the system appearance; do not force a colour scheme.
- Keep the Overview quotes card to one pending-value KPI with no overdue or due-soon breakdown.
- Keep Overview card priority ordered as bank balance, sales invoices, purchase invoices, then quotes.
- Treat WidgetKit totals as static fictional prototype data until a shared data source is explicitly added.
- Keep Dashboard as the default tab.
- Keep Invoice, Order and Quote lists on the shared Sales page template and reusable document card unless a specific exception is requested.
- Use a black page and dark-grey cards in Dark Mode; use a grey page and white cards in Light Mode.
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
