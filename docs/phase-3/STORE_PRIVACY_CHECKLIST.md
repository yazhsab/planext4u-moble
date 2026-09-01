# Store and privacy review checklist

The repository contains conservative source declarations, not legal approval.
Review the declarations against the deployed backend, provider contracts and
actual production behavior immediately before every store submission.

## All applications

- Verify package/bundle identifier, display name, category, support endpoint and
  privacy-policy endpoint from `release/store/metadata.json`.
- Confirm the privacy policy describes collection, sharing, retention, export,
  deletion, complaint and child-safety rules applicable to the target region.
- Reconcile every Apple collected-data entry and every Google Data Safety entry
  with the application binary and third-party SDK manifests.
- Confirm tracking is disabled and no data is sold. If deployed behavior differs,
  stop release and update implementation and declarations together.
- Confirm diagnostics contain operational measurements and error types only;
  never tokens, contact details, messages, payment data, KYC material or precise
  location.
- Capture screenshots from the exact signed candidate, for every required role
  surface and locale, with controlled non-personal test data.
- Validate translated title, description, release notes and screenshot copy with
  a professional language owner.
- Exercise account sign-out and the customer export/deletion workflow. Confirm
  vendor/rider lifecycle requests have an approved operational route before
  release where self-service closure is not supplied by policy.

## Customer-specific review

- Validate optional location, address, search, voice/media, purchase, payment and
  support data disclosures.
- Confirm external payment providers receive only their contractually required
  tokenized/payment information and mobile success remains webhook-authoritative.
- Validate Socio, Homes, classified safe-contact and emergency disclosures,
  consent and retention against enabled production features.

## Vendor-specific review

- Validate business identity, KYC document, bank-token, catalog/media, order,
  booking and settlement disclosures.
- Confirm private onboarding documents cannot enter public media or telemetry.
- Confirm finance/legal approval of retention and vendor account-closure handling.

## Rider-specific review

- Explain precise/background location prominently and collect it only while the
  rider is on duty under the approved contract.
- Validate proof-of-delivery media, OTP/signature evidence, earnings/bank-token
  and fraud/safety processing disclosures.
- Confirm location history access, retention and sharing are least privilege.

## Submission evidence

Archive the reviewed manifests, Data Safety answers, privacy-policy version,
localized metadata, screenshot hashes, SDK inventory, reviewer names and store
submission identifiers in the controlled release record. Legal/privacy and
store-owner sign-off are mandatory; repository validation intentionally checks
that the review status has not been mislabeled as approved.
