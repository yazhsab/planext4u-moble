# Design-system baseline

The supplied UI Design Requirements are the initial visual contract. Phase 1 will supplement them with an approved screenshot inventory of the live POC and a Figma component library.

## Foundations

| Token | Value | Primary use |
| --- | --- | --- |
| Navy | `#011D33` | Headers, primary text, dark surfaces |
| Teal | `#009999` | Primary actions, active navigation, links |
| Amber | `#F89F03` | Rewards, promotions, secondary actions |
| Canvas | `#FAFBFC` | Application background |
| Surface | `#FFFFFF` | Cards and sheets |
| Soft surface | `#F4F7FA` | Chips and section separation |
| Success | `#16A34A` | Completed and delivered states |
| Warning | `#F59E0B` | Pending states |
| Danger | `#DC2626` | Errors and destructive actions |

- Typography: Plus Jakarta Sans for display/headings, Inter for body, JetBrains Mono for identifiers.
- Spacing: 4 px scale; 16 px mobile edge padding; 16 px standard card padding.
- Radius: 12 px controls, 16 px standard cards, 20 px hero cards, 24 px sheet top corners.
- Motion: 200-300 ms ease-out for state transitions; reduced-motion alternatives are mandatory.
- Touch targets: at least 44 x 44 px.
- Accessibility: WCAG 2.1 AA, complete semantics, non-colour status cues, and 130% text scaling without breakage.

## Required component families

- Navigation shells for customer, vendor, and rider apps.
- Buttons, inputs, OTP cells, chips, status pills, cards, sheets, dialogs, toasts, and skeletons.
- Commerce cards: product, service, restaurant, order, property, classified, wallet, and promotion.
- Socio media surfaces: feed post, reel, story tray/viewer, comment sheet, DM bubble, and shopping sticker.
- Operational surfaces: map sheet, assignment card, delivery timeline, POD capture, vendor KPI tile, data table, filter bar, and audit detail.

## Fidelity gates

1. Figma component and token approval.
2. Flutter widget catalogue on phone and tablet breakpoints.
3. Golden tests in light/dark themes and EN plus one long-string locale.
4. Accessibility scan and keyboard/screen-reader walkthrough.
5. Approved visual comparison against the live POC for every retained flow.

