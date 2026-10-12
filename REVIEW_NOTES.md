# Review implementation and handoff — proposed 1.1.1

Branch: `review/uphill-sliding-1.1.1`. This is an unreleased review, not a
replacement for stable 1.0.0 or 1.1.0. No old tags or release assets were modified.

## Decisions

| Suggestion | Decision and reason |
| --- | --- |
| Consistent UphillSliding native name | Applied to source/module/class/log/friend/tests/current scripts and descriptor. Old names remain only for migration and historical beta packages. |
| Named thresholds | Applied using the exact original double values 0.0001 and 0.5; no floating-point boundary change. |
| Internal header and private dependencies | Header moved to Private; dependencies moved to Private. Confirm against real headers in the author's Engine build. |
| Prune starter dependencies further | Deferred: FactoryGame transitive header requirements cannot be established with mocks. |
| Simplify floor-normal and post-original eligibility checks | Declined: preserve every gate; another mod hook may change state during Scope. |
| Change uphill/braking thresholds or add configuration | Declined: gameplay must stay unchanged and no new configuration is required. |
| Remove shutdown unhooking | Declined: keep existing cleanup and order, including idempotence/restart regression coverage. |
| Change TGuardValue include | Existing working include retained; a speculative header change is unnecessary without the real Engine source. |
| Final 1.1.0 server documentation | Corrected from the author's explicit confirmation: Windows dedicated and Linux Docker, Epic Windows client, 2026-10-09, join/speed passed, no noticeable jitter/resets. |
| License | MIT, selected by the author. Declared in LICENSE and README; no speculative descriptor field added. |
| CI and metadata | Added SHA-pinned checkout, read-only permissions, disabled persisted credentials, push/PR tests and version-independent metadata checks. Removed completed write-capable one-off workflows without executing them. |
| Duplicate preparation scripts | Unified with Release/HistoricalBeta channel; immutable beta pins retained separately. |
| Local/personal paths and irrelevant mod parameter | Removed embedded personal ProjectRoot and RequireSmartFoundationsVersion; explicit paths are required. |
| Documentation split | BUILDING and TESTING added; original development/release-note text preserved in Docs/History with superseding notes. |
| Readable tests and NDEBUG | Named automatically counted scenarios, explicit failure reporting and expanded test doubles. Checks remain active with NDEBUG. |
| New release version | 1.1.1: maintenance/name changes, no gameplay feature addition. Native names require fresh packages, never a silent 1.1.0 replacement. |

## Validation and limits

Only `bash Tests/run-tests.sh` was run locally as the test command. All **47
scenarios per variant** pass for client/server with and without NDEBUG, compiled
with C++20 and `-Wall -Wextra -Werror`. Editor exclusion, intentional-failure
checks and descriptor metadata checks also pass. GitHub's new tests/metadata
workflows passed on the review branch.

No real Engine build, Alpakit run, Windows PowerShell 5.1 execution or in-game
1.1.1 test was possible here. Script changes were reviewed statically. The source
updater records its immutable sourceCommit and regenerated SHA256 hashes for
all payload files in Tools/Prepare-Release.ps1. The updater itself is excluded from its payload to
avoid a circular self-hash. New compiled ZIP hashes do not exist until the author
builds them. Existing stable release hashes were not changed.

### Follow-up build evidence — 2026-10-12

The author's supplied log confirms successful native Shipping builds for Epic,
Steam, WindowsServer and LinuxServer. Cooking then failed because the renamed
editor DLL was absent. The updater now explicitly builds FactoryEditor before
Alpakit; successful editor compilation, full packaging and runtime tests remain
pending at that point. A subsequent supplied log confirms successful editor
build and full Alpakit packaging, with all four expected archives present.
The author subsequently confirmed successful Windows dedicated and Linux Docker
dedicated functional tests on 2026-10-12 with the Epic Windows client after the
game update. Fresh singleplayer testing and independent archive inspection
remain pending; the brief confirmations do not establish broader acceptance
test or measured network results.
A WindowsServer release installer now validates renamed 1.1.1 packages and backs
up the previous plugin. See TESTING.md for the exact scope. Earlier mock-only statements above
describe execution in this assistant environment, not the author's machine.

## Open questions and author actions

No licensing or historical-result questions remain: the author selected MIT and
confirmed the final 1.1.0 test facts. Remaining work is validation evidence:

1. Review this draft before applying changes to the Windows development project.
2. Run the updated PowerShell 5.1 updater with explicit paths and `-CheckOnly`.
3. Apply and build all three platforms with Alpakit; regenerate IDE files and
   confirm that its automatic FactoryEditor build succeeds before cooking.
4. Confirm the Private header/dependencies and renamed AccessTransformers friend
   against actual FactoryGame/SML headers; inspect all packaged module names.
5. Complete the fresh singleplayer test and unreported broader acceptance checks
   with matching 1.1.1 packages. Windows/Linux dedicated functional tests passed
   on 2026-10-12. Record braking, sharp turns, slide jumps, jitter/resets and clean
   shutdown only when explicitly tested. See TESTING for the remaining checks.
6. Keep co-op, Steam runtime and measured latency/packet loss marked untested
   until those specific tests are performed.
7. Only after passing native builds/runtime tests, merge and create a **new**
   v1.1.1 tag/release and ficsit version with new assets/hashes.

Build steps: [BUILDING.md](BUILDING.md). Version-specific results: [TESTING.md](TESTING.md).

## Complete changed-file list

The following compares this branch to the original main commit `5491340`.
Unchanged assets, `.gitattributes`, `.gitignore` and other configuration files are
not listed. Renames explicitly list both original and new paths.

| Change | File(s) |
| --- | --- |
| Added | `.github/workflows/metadata.yml` |
| Removed | `.github/workflows/prepare-release.yml` |
| Removed | `.github/workflows/publish-v1.0.0.yml` |
| Removed | `.github/workflows/repair-release-metadata.yml` |
| Added | `.github/workflows/tests.yml` |
| Added | `BUILDING.md` |
| Updated | `CHANGELOG.md` |
| Updated | `Config/AccessTransformers.ini` |
| Added | `Docs/History/1.1.0-release-notes.md` |
| Added | `Docs/History/1.1.0-validation.md` |
| Added | `LICENSE` |
| Updated | `MULTIPLAYER.md` |
| Updated | `README.md` |
| Updated | `RELEASE_NOTES.md` |
| Renamed/updated | `Source/SlideMomentum/Private/SlideMomentum.cpp` → `Source/UphillSliding/Private/UphillSliding.cpp` |
| Renamed/updated | `Source/SlideMomentum/Public/SlideMomentum.h` → `Source/UphillSliding/Private/UphillSliding.h` |
| Renamed/updated | `Source/SlideMomentum/SlideMomentum.Build.cs` → `Source/UphillSliding/UphillSliding.Build.cs` |
| Added | `TESTING.md` |
| Updated | `Tests/CompileGuards.cpp` |
| Updated | `Tests/README.md` |
| Updated | `Tests/Regression.cpp` |
| Added | `Tests/TestSupport.h` |
| Added | `Tests/check-metadata.py` |
| Updated | `Tests/run-tests.sh` |
| Updated | `Tests/stubs/CoreMinimal.h` |
| Updated | `Tests/stubs/Engine/World.h` |
| Updated | `Tests/stubs/FGCharacterMovementComponent.h` |
| Updated | `Tests/stubs/GameFramework/Character.h` |
| Updated | `Tests/stubs/Modules/ModuleManager.h` |
| Updated | `Tests/stubs/Patching/NativeHookManager.h` |
| Added | `Tools/Historical/Beta-Pins.json` |
| Renamed/updated | `Tools/Install-Linux-Prototype.py` → `Tools/Historical/Install-Linux-Prototype.py` |
| Renamed/updated | `Tools/Install-Windows-Prototype.ps1` → `Tools/Historical/Install-Windows-Prototype.ps1` |
| Renamed/updated | `Tools/Install-WindowsServer-Prototype.ps1` → `Tools/Historical/Install-WindowsServer-Prototype.ps1` |
| Added | `Tools/Historical/Prepare-Multiplayer.ps1` |
| Added | `Tools/Historical/README.md` |
| Renamed/updated | `Tools/Repair-Release-Metadata.py` → `Tools/Historical/Repair-Release-Metadata.py` |
| Updated | `Tools/Install-Windows-Release.ps1` |
| Removed | `Tools/Prepare-Multiplayer.ps1` |
| Updated | `Tools/Prepare-Release.ps1` |
| Updated | `UphillSliding.uplugin` |
| Added | `REVIEW_NOTES.md` |
| Added | `Tools/Install-WindowsServer-Release.ps1` |
