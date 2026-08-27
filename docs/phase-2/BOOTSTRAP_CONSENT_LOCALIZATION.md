# Bootstrap, consent and localization shell

Story: `MOB-P2-006`

- Resolves the authenticated tenant/country configuration through the backend bootstrap contract.
- Blocks application content for mandatory updates and active maintenance; optional updates remain non-blocking.
- Uses a last-known-good snapshot only in an explicit offline state. With no cache, all remote flags and composed content fail closed.
- Treats absent flags as disabled and rejects unknown contract gates/locales.
- Bundles English and Tamil safety-critical copy so maintenance, update and offline screens work without CMS.
- Records append-only backend consent evidence and considers a grant valid only for the currently published policy version.

Tests cover remote/offline defaults, gates, EN/Tamil rendering, versioned consent grant/withdrawal semantics and contract rejection.
