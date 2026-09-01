# Three-phase programme — Phase 3 production-hardening exit review

**Review date:** 2026-08-30
**Scope:** customer, vendor and rider applications
**Repository status:** implemented; repository-verifiable gates must pass
**Production release status:** not approved until the external evidence below is supplied

This review concerns Phase 3 of `docs/THREE_PHASE_MOBILE_IMPLEMENTATION_PLAN.md`.
It is distinct from the older six-phase programme's Phase 3 customer-commerce
review.

## Implemented source controls

| Control | Customer | Vendor | Rider | Evidence |
| --- | --- | --- | --- | --- |
| Nine-locale runtime and translated role chrome | Complete | Complete | Complete | Shared localization catalogue and completeness test |
| Light/dark and reduced-motion behavior | Complete | Complete | Complete | Shared theme and adaptive application builder |
| Reading-order focus and live error announcements | Complete | Complete | Complete | Shared focus policy and semantic state panels |
| Low-bandwidth image opt-in and bounded decode | Complete | Complete | Complete | `Planext4uNetworkImage` and widget tests |
| Privacy-redacted runtime/API diagnostics | Complete | Complete | Complete | `MobileObservability` integration |
| Cold-start, image-paint and API budgets | Complete | Complete | Complete | Runtime metrics and release-health policy |
| Android backup/cleartext/signing hardening | Complete | Complete | Complete | Native manifests, flavor placeholders and protected signing |
| iOS privacy manifest in application resources | Complete | Complete | Complete | `PrivacyInfo.xcprivacy` and Xcode resource phases |
| Store and Android Data Safety source declarations | Complete | Complete | Complete | Versioned release metadata with mandatory review state |
| Protected signed artifact workflow | Complete | Complete | Complete | Production environment secrets, AAB/IPA build and provenance attestation |
| Progressive rollout and automatic thresholds | Complete | Complete | Complete | Versioned policy and executable evaluator |
| Source/dependency/secret scanning | Complete | Complete | Complete | Local audit plus pinned OSV and Gitleaks workflow |

The normal repository gate runs contracts, generated-token drift, formatting,
flavor policy, Phase 2 integration policy, security policy, Phase 3 release
policy, analysis and tests. Production release builds fail closed when Android
signing material is absent. The protected release workflow creates signed,
attested candidates but intentionally has no store-promotion step.

## Repository acceptance commands

```sh
dart run melos run verify
dart run tool/evaluate_release_health.dart \
  --input=release/rollout/healthy-sample.json \
  --stage=internal
```

A complete repository acceptance run also compiles customer, vendor and rider
for development, staging and production on Android and iOS. Debug and simulator
builds prove current source/native integration; they do not substitute for
signed device testing.

## Verification evidence — 2026-08-30

- `dart run melos run verify` passed all 11 packages/applications, including
  generated contract hash
  `332ef63e39ef8f7e4dc13a25709b697f288fbb66061f29f73ecf0ee7a8db4b0f`.
- All nine Android debug APKs compiled from the current source: three roles by
  development, staging and production.
- All nine iOS simulator applications compiled from the current source for the
  same role/flavor matrix.
- Every built iOS application included the role-owned `PrivacyInfo.xcprivacy`;
  dependency privacy manifests were also present in their owning bundles.
- The healthy rollout fixture evaluated to `advance` from `internal` to
  `cityPilot`; hold and rollback thresholds are unit tested.
- Production Android release tasks were verified to reject absent protected
  signing material.

## External evidence required before production approval

| Owner | Required evidence | State |
| --- | --- | --- |
| Product and language owners | Professional review of all nine locales in role-specific real data states | Required |
| Accessibility QA | VoiceOver/TalkBack, dynamic type, contrast, switch/keyboard and reduced-motion device report | Required |
| Platform engineering | Protected Firebase/APNS/maps/media/WebRTC/payment configuration and successful signed workflow run | Required |
| Security | SAST triage, mobile binary assessment, API penetration test and zero open P0/P1 findings | Required |
| Privacy/legal | Apple privacy manifest, Google Data Safety, retention, export/deletion and emergency-data approval | Required |
| Performance/SRE | Calibrated device, load, soak, chaos and disaster-recovery results against production-equivalent systems | Required |
| Finance/risk | Payment, refund, settlement, KYC and reconciliation approval | Required |
| Operations/support | City readiness, emergency responder process, support training, escalation and incident rehearsal | Required |
| Release manager | Signed AAB/IPA provenance, physical-device matrix and store metadata/screenshots | Required |
| Executive change authority | Six required approvals recorded before first production promotion | Required |

## Exit decision

The Phase 3 repository implementation is complete when its full quality gate and
native compile matrix pass. Production rollout remains deliberately blocked by
the external evidence table. No credential, provider response, security result,
store approval, physical-device result or business approval is inferred from
source code.
