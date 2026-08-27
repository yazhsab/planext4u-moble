# Planext4u storage

Authenticated AES-256-GCM cache records and a bounded idempotent offline command queue. The data-encryption key is generated independently and held by platform Keychain/Keystore storage. Cache files contain ciphertext only and are atomically replaced.
