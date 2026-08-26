# Role and permission matrix v0.1

Backend policies are authoritative. Mobile/admin clients use permissions only to shape navigation and prevent confusing actions; hidden controls never replace authorisation.

Legend: `R` read, `C` create, `U` update, `A` approve/administrate, `S` scoped to owned/assigned records, `-` no access.

| Domain | Customer | Vendor | Service vendor | Restaurant | Rider | Franchise admin | Field officer | Support | Moderator | Finance | Ops admin | Super admin |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Own profile/consent/devices | RCU | RCU | RCU | RCU | RCU | RCU | RCU | RCU | RCU | RCU | RCU | RCU |
| Customer profiles | S | - | - | - | S | RS | S | RS | R | R | RA | A |
| Vendor profile/KYC | R | RCU-S | RCU-S | RCU-S | - | RUA-S | RCU-S | R-S | RA | R | RA | A |
| Rider profile/KYC/attendance | S | - | - | R-S | RCU-S | RUA-S | RCU-S | R-S | R | R | RA | A |
| Franchise/field operations | - | R-S | R-S | R-S | R-S | RCUA-S | RCU-S | R-S | - | R | RA | A |
| Catalog/products/services | R | RCU-S | RCU-S | RCU-S | R | RU-S | - | R | RA | R | RA | A |
| Inventory/availability | R | RCU-S | RCU-S | RCU-S | R-S | RU-S | - | R-S | - | R | RA | A |
| Cart/checkout/payment | RCU-S | R-S | R-S | R-S | - | R-S | - | R-S | - | R | RA | A |
| Orders/bookings | RCU-S | RU-S | RU-S | RU-S | RU-S | RUA-S | R-S | RU | R | R | RA | A |
| Dispatch/live location/POD | R-S | R-S | RU-S | RU-S | RCU-S | RUA-S | R-S | R-S | - | R | RA | A |
| Wallet/rewards/referrals | RCU-S | R-S | R-S | R-S | R-S | R-S | - | R-S | - | RUA | R | A |
| Payments/refunds/settlements | R-S | R-S | R-S | R-S | R-S | R-S | - | R-S | - | RCUA | RA | A |
| Promotions/ads/CMS | R | RCU-S | RCU-S | RCU-S | - | RU-S | - | R | RUA | R | RUA | A |
| Socio content | RCU-S | RCU-S | RCU-S | RCU-S | RCU-S | R-S | - | R-S | RUA | - | R | A |
| Homes/classifieds | RCU-S | RCU-S | RCU-S | - | R | R-S | R-S | R-S | RUA | R | RA | A |
| Emergency operations | RCU-S | R-S | R-S | R-S | RCU-S | RUA-S | RCU-S | RUA | R | - | RA | A |
| Notifications/support | RCU-S | RCU-S | RCU-S | RCU-S | RCU-S | RUA-S | RCU-S | RCUA | R-S | R | RA | A |
| Reports/exports | R-S | R-S | R-S | R-S | R-S | RUA-S | R-S | R-S | R-S | RCUA | RUA | A |
| Feature flags/country/config | R | R-S | R-S | R-S | R | R-S | R | R | R | R | RUA | A |
| Audit/session/security events | S | S | S | S | S | R-S | R-S | R-S | R-S | R-S | RA | A |

## Privileged-action requirements

- MFA and fresh reauthentication: KYC decision, bank change approval, manual wallet adjustment, refund override, settlement approval/payment, permission changes, policy publication and audit export.
- Four-eyes approval candidates: settlement payment, high-value wallet adjustment, bulk refund, tax configuration and destructive master-data operations.
- All privileged mutations require actor, target, reason, before/after, correlation ID, country/tenant, timestamp and source IP/device evidence where legally appropriate.
- Scoped roles must be enforced by server-side resource ownership/territory policies, never request parameters alone.
