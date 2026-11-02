# Mobile-first completion: Phase 0

The new completion programme uses the versioned [Phase 0 register in the backend repository](../../../planext4u-backend/docs/completion/phase-0/README.md). It covers all three Flutter apps, the Go backend and `admin-web`. Its numbering is distinct from the historical delivery phases in this repository.

Per the user's 2026-10-24 clarification, owner roles are sufficient and deployment testing targets the local stack first. Remote QA/UAT follows when server details are supplied. Continue using the accepted three-app, India-first, Go platform and separate administrator deployment decisions.

The [four Phase 0 acceptance criteria](../../../planext4u-backend/docs/completion/phase-0/phase-0.json) now pass for the authorized local scope as `PASSED_WITH_DEFERRALS`. Phase 1 is unblocked. iOS remains UNAVAILABLE and required before native iOS acceptance/release; no build pass is inferred. From the sibling backend repository run:

```text
node scripts/completion/check.mjs gate
```

Mobile evidence must include clean dependency resolution and `dart run melos run verify`, all three Android flavor builds and all three iOS flavor builds using the pinned CI tooling, and real persistent local role journeys. The user explicitly instructed on 24 October 2026: "Keep iOS pending; continue locally". The iOS matrix remains pending with no build pass claimed; no push or remote CI run is authorized by that instruction. The in-memory staging slice and fixture screenshots do not establish owner-service integration. Record source revisions and test artifacts in the shared evidence register.

## Local Android build matrix on Windows

The installed local test tools are Flutter 3.41.4/Dart 3.11.1, Temurin JDK 17.0.20.1+1 and Android command-line tools 22.0. The SDK contains `platforms;android-37.0`, API 36, Build Tools 35/36 and NDK 28.2.13676358. Native dependencies also request API 34/35 and CMake 3.22.1; the first Gradle build installs those using the accepted SDK licenses. The package name is `platforms;android-37.0`, rather than `platforms;android-37`.

From the mobile repository run:

```powershell
& .\tool\verify_android.ps1 `
  -FlutterSdk 'C:\tmp\planext4u-review-tools\flutter' `
  -JavaHome 'C:\tmp\planext4u-review-tools\jdk-17.0.20.1+1' `
  -AndroidSdk 'C:\tmp\planext4u-review-tools\android-sdk' `
  -GradleUserHome 'C:\tmp\planext4u-review-tools\gradle-cache'
```

Use the installed tool locations on another machine. The helper sets environment variables only for its execution and restores them afterward. It uses the supplied Gradle home, without an individual's existing Gradle settings. Resolve the locked Flutter dependencies first. The helper builds all nine app/flavor combinations, verifies each APK's manifest application ID, and records source revision/fingerprint, exit codes, artifact sizes and SHA-256 values under ignored `build/phase0-android/report.json`. Per-build logs and APKs remain local. `-Apps`/`-Flavors` can select a diagnostic subset; `complete_all_nine` remains false for that subset.

These are debug compile/packaging checks, including the production **flavor**. They do not sign a production release, activate providers, launch an app against a remote API, publish to a store, prove device behavior or satisfy the full Phase 0 gate. The complete Linux Flutter gate now also passes (295 tests in 11 packages); all eight Linux design-system snapshots were regenerated on Linux and visually reviewed. Real local API/BFF role checks and administrator browser verification run against the Docker/WSL2 stack. Native device journeys and macOS/iOS verification remain separate checks.
