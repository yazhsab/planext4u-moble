# Encrypted cache and offline command foundation

Story: `MOB-P2-010`

`planext4u_storage` encrypts each cache record with AES-256-GCM and binds ciphertext to its namespace and record key as authenticated associated data. A random data key is held separately in platform Keychain/Keystore storage. Files are bounded, atomically replaced and contain ciphertext only.

Every cache entry has independent fresh and stale cutoffs. Expired and corrupt entries are deleted immediately. Logout can purge all ciphertext and destroy the data key.

The offline command queue is encrypted, serial, ordered and bounded by command count and encoded bytes. Only an explicit operation allow-list is accepted; every command requires an idempotency key and expiry. Duplicate keys collapse, retryable failure stops ordering for reconnect, and permanent/expired commands are discarded. Diagnostics contain only command ID, operation and outcome—never payloads or credentials.

Tests cover encryption, associated-data tampering, fresh/stale/expired policy, corruption, file replacement, logout purge, deduplication, offline/reconnect ordering, expiry, permanent failure, operation allow-list and credential rejection.
