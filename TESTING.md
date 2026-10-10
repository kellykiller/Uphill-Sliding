# Test status and acceptance checks

## Author-confirmed final 1.1.0 results

The author explicitly confirmed the following final-release results on 2026-10-10,
for sessions performed on **2026-10-09**. These are manual author reports, not
independently recorded client videos or packet traces.

| Package and session | Client | Result |
| --- | --- | --- |
| Final 1.1.0, Windows singleplayer | Epic Windows | Uphill-sliding smoke test passed |
| Final 1.1.0, Windows dedicated server | Epic Windows | Join and uphill speed retention passed; no noticeable jitter or position resets |
| Final 1.1.0, Linux Docker dedicated server | Epic Windows | Join and uphill speed retention passed; no noticeable jitter or position resets |

Environment: Satisfactory **1.2.4.0 (build 502094)**, SML **3.12.0**.
This confirmation supersedes the earlier beta-only dedicated test descriptions.
It does not establish results for unreported test cases.

Still untested: directly hosted co-op/listen host and guest, Steam client runtime,
systematic latency/packet loss, two simultaneous players, collision and respawn
acceptance checks. Absence of noticeable jitter in the reported sessions is not
a measured network-correction benchmark.

## Build and archive evidence for 1.1.0

Final Alpakit packaging passed for Windows clients (Epic and Steam), WindowsServer
and LinuxServer on 2026-10-09. The supplied final build log reported success and
exit code 0. Independent inspection verified platform descriptors, SML module
manifests, Windows PE and Linux ELF binaries, ZIP integrity and cooked content.
A subsequent descriptor-only repair corrected numeric `Version` from 2 to 1;
native binaries and cooked content were unchanged.

Published corrected `UphillSliding.zip` SHA256:
`3c489eb32fb4eeb43ed0ddd848c90b79cff24336cfbe62497cd5fbcbf9a77bbf`.

The complete beta/build chronology, original hashes, log observations and the
metadata repair are preserved in [the historical record](Docs/History/1.1.0-validation.md).
Neither existing release assets nor tags are changed by this review.

## Proposed 1.1.1 validation

The native module, class, logging category and binary names are now `UphillSliding`.
Gameplay conditions, thresholds, network routing, hook order and cleanup remain
unchanged. The new binary names require rebuilding every platform.

`bash Tests/run-tests.sh` passes **47 scenarios per variant**: client, dedicated
server, and each with `-DNDEBUG`. Editor exclusion, expectation failure handling
and generic descriptor metadata checks also pass. Compilation uses C++20 with
`-Wall -Wextra -Werror`. Tests compile actual mod code against mock engine/SML headers.

**No real Engine build or in-game test of renamed 1.1.1 has been performed here.**
Mocks do not establish compatibility with real FactoryGame headers or native ABI,
packaging, collision physics, saved moves, replication or packet delivery.
The 1.1.0 reports above must not be presented as tests of 1.1.1.

Before publishing 1.1.1, the author must:

1. Build with Alpakit for Windows clients, WindowsServer and LinuxServer.
2. Check that all `.modules` manifests name `UphillSliding` and that no legacy
   `SlideMomentum` binaries or source directories remain in the new archives.
3. Install matching 1.1.1 packages on every participating client and server.
4. Retest singleplayer and both dedicated server platforms: joining, uphill
   speed, reverse-input braking, sharp turns, slide jumps and normal shutdown.
   Watch for jitter and position resets, and compare with the mod disabled.
5. Record the actual packages, platform/client, date and observed results here.
   Keep co-op and Steam runtime marked untested until those sessions are run.

## Acceptance tests

| Test | Expected result |
| --- | --- |
| Gentle walkable ramp from a fast slide | Momentum carries uphill without repeated snapping backward |
| Chain downhill, uphill, slide-jump and landing | Normal slide/jump state stays consistent |
| Release crouch, reverse input, sharp turn | Normal braking and sharp-turn limits remain |
| Wall, edge, unwalkable slope, airborne phase | No speed restoration through collisions or walking up walls |
| Two connected players, both moving | Both receive the effect and see the other's movement normally |
| Reconnect, death/respawn, save/reload | Hooks continue working on new player pawns |
| Typical latency, then higher latency/packet loss | No sustained corrective jitter or velocity disagreement |
| Client lacks mod / server lacks mod / wrong version | SML rejects incompatible connections |
| Singleplayer regression | Previous uphill behavior still works |

Complete the remaining acceptance tests on Windows and Linux dedicated servers,
then repeat on a listen server, testing both host and joining player. Dedicated
server success alone does not validate listen-host and guest behavior.

## How movement is applied

The same four hooks run on the owning client's autonomous proxy (prediction and
re-evaluation) and on authority-controlled player characters, including remote
players on dedicated and listen servers. Client simulated proxies are excluded;
other players are displayed through normal replicated movement.

The calculation uses crouch input, acceleration, velocity, sliding state and the
walkable floor. It adds no persistent movement state or custom RPCs. FactoryGame
already declares saved slide state and compressed-flag handling in its movement
implementation. This makes using the existing movement pipeline a reasonable
first implementation; real server corrections must still be measured.

The normal collision solver and position validation stay enabled. Walkability,
reverse-input braking, sharp-turn checks, and original slide eligibility remain.
The former local Enabled console variable is removed to prevent divergent rules.
There are no player configuration or diagnostic console options in 1.1.0.

`RequiredOnRemote` is true. `RemoteVersionRange` is omitted, so SML requires the
exact same mod version on both sides. Do not mix 1.1.0, its beta packages or 1.0.0 in a session.

