# Customer home and catalog-read slice

Story: `MOB-P2-008`

The customer application now uses the shared production theme/localization with four permission-ready destinations: Home, Explore, Activity and Profile. Home consumes backend categories and featured items with integer-money display, responsive phone/tablet grids, pull-to-refresh and explicit loading, empty, error, offline, stale and degraded variants.

The typed catalog client covers home, category, item, search and opaque-cursor item reads. Last-known-good data is visibly marked offline and degraded backend results are never cached as fresh.

Deep links are limited to `/app`, `/app/home`, `/app/catalog` and `/app/catalog/items/{safe-id}`. Admin/vendor/rider paths and unsafe identifiers are rejected. Widget and controller tests cover customer navigation, home rendering, catalog deep links, projection states and contract decoding.
