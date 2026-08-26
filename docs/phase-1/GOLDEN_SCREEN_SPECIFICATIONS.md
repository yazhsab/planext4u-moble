# Golden screen specifications

## Approval and source format

The Phase 1 visual baseline is the supplied UI requirements plus the tokens in [Design-system baseline](../DESIGN_SYSTEM_BASELINE.md). The SVG files in `golden/` are original, Figma-importable reference compositions; they do not contain copied POC assets or production data.

| Reference | Viewport | Primary requirement families | File |
| --- | --- | --- | --- |
| Customer home | 390 x 844 | `P4U-CS-*`, `P4U-MKT-*`, `P4U-WAL-*` | [customer home](golden/customer-home.svg) |
| Product detail | 390 x 844 | `P4U-MKT-*` | [product detail](golden/product-detail.svg) |
| Vendor dashboard | 390 x 844 | `P4U-VND-*` | [vendor dashboard](golden/vendor-dashboard.svg) |
| Rider active task | 390 x 844 | `P4U-RDR-*`, `P4U-ORD-005` | [rider active task](golden/rider-active-task.svg) |
| Administrator dashboard | 1440 x 900 | `P4U-ADM-*`, `P4U-RPT-*` | [administrator dashboard](golden/admin-dashboard.svg) |

## Composition rules

- Customer, vendor and rider screens use a 390-pixel reference frame, 16-pixel edges, 8-pixel grid and 44-pixel minimum interactive targets.
- Administrator uses a 240-pixel navigation rail, 64-pixel top bar and responsive 12-column content grid.
- Navy provides hierarchy, teal represents primary/active action, amber represents reward/promotion and semantic colours always include text/icon cues.
- Cards use 16-pixel radius and controls use 12-pixel radius. Shadows are subtle and never the only boundary.
- A sticky or bottom action must preserve safe-area padding and remain reachable with 130% text.
- Live maps, product media and avatars use neutral original placeholders in golden sources; production assets are content, not design tokens.

## Reference intent

### Customer home

- Location and notification controls appear before personalised content.
- Search spans the primary column; module shortcuts expose Shop, Services, Food, Homes, Classifieds and Socio according to server flags.
- Wallet is informational; tapping it never performs a financial mutation.
- Emergency is visually distinct, carries a disclaimer entry and remains disabled when its release gate is false.
- Loading, partial-content, offline-cache, empty-location and mandatory-update variants share the same information hierarchy.

### Product detail

- Media, title/vendor trust, rating, price, variants, stock/delivery and policy context precede purchase actions.
- Server revalidation occurs on cart/buy. Disabled controls explain stock, location, policy or network cause.
- Tabs cover description, specifications, reviews and Q&A without losing the purchase context.
- Sticky Add to cart / Buy now controls respect keyboard, safe-area and text scaling.

### Vendor dashboard

- Verification/KYC status is persistent until complete and links to the next required action.
- Sales, orders, inventory and settlement tiles are server-calculated and show freshness.
- Quick actions are permission/config driven; unavailable actions are explained rather than silently broken.
- Alerts prioritise rejected catalog, low stock, booking conflict, payout hold and expiring documents.

### Rider active task

- Safety-first map keeps the next required action, pickup/drop summary and escalation available.
- State buttons are driven by the server state machine and queue offline commands with visible sync state.
- Contact actions use masked/consented channels.
- POD requires configured OTP/photo/signature evidence and cannot be edited after server acceptance.

### Administrator dashboard

- Navigation is permission and country/tenant scoped.
- KPIs link to actionable, filter-preserving queues and show time range/freshness.
- Privileged actions require MFA/fresh auth and, where configured, four-eyes approval.
- Tables support server pagination, saved filters, accessible sort, audit context and sanitised queued export.

## Required golden variants in Phase 2

Every reference becomes Flutter widget/golden coverage for:

1. Light and dark themes.
2. 390-pixel phone and 768-pixel tablet layouts; admin at 1366 and 1440 widths.
3. English and Tamil long-string fixtures.
4. Loading, empty, error, offline-stale and permission-denied states.
5. Text scale 1.0 and 1.3.
6. Reduced motion and high-contrast focus/semantics evidence.

## Phase 1 acceptance

- Original sources use only approved tokens and synthetic content.
- The five priority role/flow compositions cover the shared component families needed for Phase 2.
- Responsive/accessibility/state requirements are explicit and testable.
- Figma import is optional for collaboration; Flutter token/component code remains canonical.
