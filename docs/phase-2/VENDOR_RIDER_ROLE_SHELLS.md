# Vendor and rider authenticated shells

Story: `MOB-P2-009`

Vendor and rider applications now render navigation from three independent server-controlled inputs: an exact application role, granted capabilities and explicit feature flags. A missing role denies the whole shell; a missing capability hides the destination; unpublished flags default off.

Vendor destinations cover overview, orders, catalog, earnings and profile. Rider destinations cover duty, assignments, earnings, emergency and profile. Domain workflows remain clearly labelled Phase 2 surfaces until their owning service contracts land; there are no reachable unflagged placeholders.

Policy and widget tests cover cross-role denial, absent capability, absent flag and permitted navigation.
