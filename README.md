# Sage Active iOS Prototype

A native SwiftUI prototype for exploring the information architecture of a mobile business-finance dashboard. It uses fictional Spanish business data and Apple’s own interface and chart components.

This is a research prototype. It is not an accounting system and makes no claim of tax or legal compliance.

## What is included

- An Overview for current bank balance and actionable invoice totals.
- A Bank Balance page with W, M, 3M, 6M and Y forecasts.
- Paired money-in and money-out bars with native chart selection.
- An Insights view with month, year and fiscal-year controls.
- Revenue and purchase comparisons.
- Top-five customer and product/service rankings, plus “all other”.
- An optional Include IVA setting for analytical values.
- Read-only sales and purchase invoice lists and details.
- Safe simulated reminder feedback; no messages or data leave the app.
- Native pull-to-refresh with a short simulated delay.
- Native semantic page and card colours that adapt to system appearance.
- Bank-account inclusion controls and six native chart-colour choices.
- Visible chart callouts when a chart is pressed and dragged.
- A pending-quotes KPI on Overview.
- A native WidgetKit Home Screen widget for unpaid sales and purchase invoices.
- A temporary monochrome app icon and the Home Screen name `Sage Active`.

## Run it in the iPhone Simulator

1. Open `SageActiveiOSPrototype.xcodeproj` in Xcode.
2. At the top of Xcode, select the `SageActiveiOSPrototype` scheme if it is not already selected.
3. Select an iPhone 17 Pro simulator running iOS 26.3.1.
4. Press the triangular Run button, or press Command–R.
5. Wait for the Simulator to open. The app starts on the Overview.

No developer account, API key, server, package installation or real bank connection is required for the Simulator build.

## Add the Home Screen widget

1. Run Sage Active at least once after installing it. Apple requires this before a new widget appears in the widget gallery.
2. Return to the iPhone Home Screen.
3. Touch and hold an empty area, then choose to add a widget.
4. Search for `Sage Active` and select `Invoice actions`.
5. Choose the small or medium size and add it to the Home Screen.

The prototype widget displays the same fictional gross unpaid totals as the Overview dataset: `10.000 €` of sales invoices and `7350 €` of purchase invoices. It uses a static timeline for now. A later API or shared-data phase can keep it synchronized with live app data.

## Add Dark Mode to Control Centre

The app and widget follow the iPhone’s system appearance automatically; there is no app-specific appearance override.

1. Open Control Centre.
2. Touch and hold an empty area to edit it.
3. Tap `Add a Control`.
4. Select Apple’s `Dark Mode` control.

After it is added, use that control to switch Sage Active between Light and Dark Mode.

## Where to make common prototype changes

- `Resources/prototype-dataset.json`: all fictional businesses, accounts, invoices, history and rankings.
- `Features/Home/HomeView.swift`: Overview/Insights switch, settings and Overview cards.
- `Features/BankBalance/BankBalanceView.swift`: forecast and cash-flow charts.
- `Features/Insights/InsightsView.swift`: historical comparisons and rankings.
- `Features/Invoices/InvoiceViews.swift`: read-only invoice routes.
- `SageActiveWidgets/SageActiveWidgets.swift`: the Home Screen KPI widget.
- `Shared/PrototypeCard.swift`: the reusable card container.
- `Shared/Formatting.swift`: Spanish dates, euros and percentages.
- `Data/PrototypeStore.swift`: calculations and mock-data access.
- `Data/DatasetValidator.swift`: automatic consistency checks for mock data.

If you ask Codex for a change, describe the user outcome first, name the screen, explain what must remain unchanged, and ask it to build and verify the result in the iPhone 17 Pro simulator.

## Working with the mock data

Money is stored as integer cents. For example, `4825000` means `48.250,00 €`. This avoids rounding errors.

The app validates the dataset every time it loads. It checks invoice arithmetic, IVA arithmetic, Spanish locale assumptions, ranking references and ranking totals. If a future edit breaks those relationships, the app shows a data-unavailable state rather than presenting misleading values.

## Design-system tokens later

The current version deliberately uses standard native styling so information architecture can be evaluated first. Its small semantic layer maps the page to Apple’s `secondarySystemBackground` and cards to `systemBackground`, with shared spacing and corner-radius values in `PrototypeCard.swift`. A later styling phase can replace those mappings with company design-system tokens while retaining native controls.

## Reference environment

- Xcode 26.3
- iOS 26.0 deployment target
- iPhone 17 Pro simulator on iOS 26.3.1
- SwiftUI, Swift Charts and Observation
- No external Swift packages
- No network access, authentication or analytics

## Known prototype boundaries

- All customers, invoices, forecasts and account values are fictional.
- Quotes and WidgetKit invoice totals are also fictional.
- Bank institutions currently use compact text badges. Approved logo artwork can replace these when supplied.
- Forecasts are deterministic demonstrations based on invoice expected-cash dates; they are not financial predictions.
- Fiscal year currently follows the Spanish scenario’s calendar year.
- The app has not been prepared for TestFlight or production signing.
