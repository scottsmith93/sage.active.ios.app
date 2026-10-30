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
- Sage Graphite semantic page, card, text and status colours that adapt to system appearance.
- Bank-account inclusion controls and six native chart-colour choices.
- Visible chart callouts when a chart is pressed and dragged.
- A pending-quotes KPI on Overview.
- A native WidgetKit Home Screen widget for unpaid sales and purchase invoices.
- A temporary monochrome app icon and the Home Screen name `Sage Active`.
- A native bottom tab bar with Dashboard as the default and a new Sales destination.
- Shared searchable, sortable and filterable lists for invoices, orders and quotes.
- Compressed BBVA, CaixaBank and Santander artwork supplied for this prototype.
- A green native accent for primary actions, selected Sales filters and the active tab.
- Dashboard-owned chart colour choices shared by Insights and Bank Balance cash-flow charts.
- A native Create Sales Invoice journey with customer, date, prefix and product selection.
- A 20-item fictional café-supply catalogue with editable price, quantity, discount and description fields.
- Reusable sales line-item cards, live taxable-amount calculations and an expandable floating invoice summary.

## Run it in the iPhone Simulator

1. Open `SageActiveiOSPrototype.xcodeproj` in Xcode.
2. At the top of Xcode, select the `SageActiveiOSPrototype` scheme if it is not already selected.
3. Select an iPhone 17 Pro simulator running iOS 26.3.1.
4. Press the triangular Run button, or press Command–R.
5. Wait for the Simulator to open. The app starts on the Overview.

No developer account, API key, server, external package download or real bank connection is required for the Simulator build.

## Explore the business card

Card artwork follows Figma Banking frame `88:34999`. The Sage logo, chip, contactless mark, Mastercard mark and background are local SVG assets with vector preservation enabled. Balance and cardholder text remain native and use fictional data. The animated border uses a muted green palette; a tiny card thumbnail replaces the navigation title after the card scrolls out of view.

In Dashboard → Overview, tap the business card above the bank balance. The dashboard’s ellipsis demo configuration includes Show business card, remembered between launches. Empty sales invoices, purchase invoices and quotes show their title and a secondary plus-icon action, with 8-point spacing/vertical padding and no subtitle. Create invoice and Create quote use the shared sales document composer; Upload receipt opens the native image/PDF picker and saves a local copy under PurchaseReceipts for review, without creating a purchase invoice. Turning it off hides the card and its dashboard approval prompt, while the bank balance remains available. The card compresses while pressed and springs back on release, respecting Reduce Motion. Its green border has an eight-second animation with a narrow shine. On devices with motion hardware, Core Motion drives calibrated three-axis perspective tilt (up to 8° pitch/roll and 2.5° twist), a bright specular reflection with gradual feathered edges and softly fading corner glints. One shared 30 Hz sensor session serves visible cards, maps movement to each window’s orientation, and stops when no card needs it. Reduce Motion and accessibility card layouts stay still; backgrounding pauses the effect. Motion samples stay in memory on the device. Judge the tilt and reflection feel on a physical device; simulator layout checks do not validate live sensor movement. The card page has searchable transactions grouped by date, All and Needs invoice filters, and a card-management button in the top toolbar. In a wide, regular-size-class Duo layout, the usable area splits exactly 50/50 into independently scrolling Card overview and Transactions panes under one Business card page title. The overview shows issuer-owned monthly/per-transaction limits and read-only online/recurring payment permissions. Spend is calculated from the latest fictional transaction month, including refunds and excluding unapproved payments. Narrow layouts retain the existing stacked page; larger accessibility text on the wide display stacks the issuer information too. Freeze/unfreeze and PIN controls live in the management sheet. Transaction details open in a large sheet with a floating primary-colour glass invoice attachment action over a softly fading native material blur. The footer action disappears after attachment; View invoice sits inside the attachment container and opens either the selected file or a fictional invoice preview. In-person purchases show a scrolling Apple Maps hero subdued by a 50% page-colour overlay, fading into an opaque details background. The first content slightly overlaps the map; the rest retains a permanent page background. The header starts clear and gains the native soft scroll-edge blur when details reach it. The pin uses a fictional merchant location without requesting the device location. Selected fictional payments show a noninteractive Apple Pay mark rendered by PassKit. Online transactions have no map. The native attachment action sheet offers Scan receipt (camera photo) or Upload (PDF/image from Files). The simulator has no camera; Upload remains available. Files and matching metadata are saved on this device; no web admin service is connected.

Manage card provides masked card details and PIN reveal through an explicitly simulated Face ID check. The Card details heading sits above its container; every detail has a copy action. Copying a masked number or security code verifies first. Copied values expire after two minutes on the local clipboard; a green glass confirmation slides in for three seconds. Freeze scatters 110 snowflakes over a transparent background and plays a short, locally synthesized wind cue at low volume. The frozen-card message appears immediately below the controls, above Card details, with stacked full-width secondary Report fraud and Order a new card actions. These open guidance alerts; they do not submit reports or replacement orders. Revealed details hide after 30 seconds; the PIN closes after 15 seconds. Both hide when the app leaves the foreground. All cardholder, card and transaction details are fictional.

To demonstrate notifications, open the bell button on the card page, choose a purchase or approval request, and allow notifications when asked. Lock the simulator using its Device menu within 8 seconds. Tap the notification to open the matching transaction. At the scheduled approval-notification delivery time, an Approval required card appears above the dashboard Overview/Insights toggle, showing Paperchas and 129,00 €, a ten-minute countdown with a Sage progress ring, and a primary Review action that opens the same approval route. Its deadline persists across relaunches; approval or expiry removes the dashboard card, and an expired request cannot be approved. Approval requests open a compact sheet for Paperchas, showing 129,00 € and SVG Sage S / merchant marks. Confirm payment swaps the content to a Face ID prompt. Confirm payment with Face ID invokes Apple LocalAuthentication (not simulated in-app); only successful authentication advances to a 2.2-second processing state and Payment successfully confirmed, with Close. A frozen card blocks approval. In Simulator, enable Features → Face ID → Enrolled before the demo, then use Features → Face ID → Matching Face while authentication is pending. On a physical device, Face ID must be set up. iOS controls the system authentication presentation. Scheduling another approval request resets that fictional approval for another demonstration.

Deep links use `sageactive://card` and `sageactive://card/transaction/purchase` (or `approval`). The `-showBusinessCard` launch argument opens the card page directly. Freeze status, invoice attachments and approval decisions persist between launches.

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
- `Features/Sales/SalesView.swift`: the shared Sales list, document filters, sorting and reusable document card.
- `Features/Sales/CreateSalesInvoiceView.swift`: invoice creation, selection sheets, product editing and invoice summary.
- `Features/BusinessCard/`: card artwork, activity, card controls, attachments, approval state and local notification routing.
- `SageActiveWidgets/SageActiveWidgets.swift`: the Home Screen KPI widget.
- `Shared/SageActiveTheme.swift`: the single adapter from app-facing semantic roles to Sage Graphite tokens.
- `Shared/PrototypeCard.swift`: the reusable card container, bank badges and chart-colour picker.
- `Shared/Formatting.swift`: Spanish dates, euros and percentages.
- `Data/PrototypeStore.swift`: calculations and mock-data access.
- `Data/DatasetValidator.swift`: automatic consistency checks for mock data.

If you ask Codex for a change, describe the user outcome first, name the screen, explain what must remain unchanged, and ask it to build and verify the result in the iPhone 17 Pro simulator.

## Working with the mock data

Money is stored as integer cents. For example, `4825000` means `48.250,00 €`. This avoids rounding errors.

The app validates the dataset every time it loads. It checks invoice arithmetic, IVA arithmetic, Spanish locale assumptions, ranking references and ranking totals. If a future edit breaks those relationships, the app shows a data-unavailable state rather than presenting misleading values.

## Sage Graphite tokens

The app keeps Apple-native controls and behaviour, while `SageActiveTheme` maps its semantic colour roles to the Sage Graphite iOS package. Feature views do not import Graphite directly. This boundary allows the legacy `Theme.GRColorPalette` implementation to be replaced by the future `DSTokens` API in one place.

For reliable prototype builds, `Packages/SageGraphiteTokens` contains an authorised local snapshot of only the Graphite colour tokens. It was taken from the private repository's `develop` download on 10 August 2026. The snapshot deliberately excludes Graphite UI components, third-party image libraries and build-tool plugins. Replace it with an approved versioned DS token package when one becomes available.

Spacing and corner-radius values remain app-owned because this Graphite snapshot does not yet expose stable semantic DS geometry tokens.

## Reference environment

- Xcode 26.3
- iOS 26.0 deployment target
- iPhone 17 Pro simulator on iOS 26.3.1
- SwiftUI, Swift Charts and Observation
- A local Sage Graphite token-only Swift package
- No runtime or build-time network access, authentication or analytics

## Known prototype boundaries

- All customers, invoices, forecasts and account values are fictional.
- Quotes and WidgetKit invoice totals are also fictional.
- The supplied bank logos are compressed prototype assets and remain visual only; there are no real bank connections.
- Sales orders use local fictional fixtures until the example-data source is connected.
- Two fictional invoices intentionally share an issue date to demonstrate grouped document cards.
- Creating an invoice remains a local prototype interaction; it does not persist a new document or call an API.
- Forecasts are deterministic demonstrations based on invoice expected-cash dates; they are not financial predictions.
- Fiscal year currently follows the Spanish scenario’s calendar year.
- The app has not been prepared for TestFlight or production signing.
