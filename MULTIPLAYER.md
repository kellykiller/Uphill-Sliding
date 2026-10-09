# Multiplayer validation and development — 1.1.0

The first real-engine client/server build and archive verification passed on
2026-10-09. The Linux Docker server subsequently loaded the native module and activated the
beta successfully. The author then joined from the Epic Windows client and
reported successful uphill sliding. A comparison with both SML and the mod
removed reproduced the immediate stop on a slight uphill slope.
The author also completed a Windows Server 2025 dedicated test with the Epic
Windows client: vanilla uphill sliding stopped as expected, then the matching
beta worked after installation on client and server. The author reported success
when asked about joining, retained speed, jitter and position resets.
The 1.1.0 release source retains the tested beta movement rules. Diagnostic
console options and per-slide logs are removed, and release metadata is finalized.
Final real-engine 1.1.0 packaging and archive checks passed on 2026-10-09;
existing beta ZIPs remain separate beta packages.
The published 1.0.0 package remains singleplayer only.

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

## Build on Windows

Use the existing matching SML starter project and UE 5.6.1-CSS installation.
Install Epic's **v25 clang-18.1.0-based Linux cross-compilation toolchain** on the
Windows development machine, then open a new PowerShell window.

Official downloads and setup:
- [Satisfactory modding requirements](https://docs.ficsit.app/satisfactory-modding/latest/Development/BeginnersGuide/dependencies.html#_clang_toolchain_for_linux_dedicated_server_support)
- [Epic toolchain table for UE 5.6](https://dev.epicgames.com/documentation/en-us/unreal-engine/linux-development-requirements-for-unreal-engine?application_version=5.6)

`Tools/Prepare-Release.ps1` is a standalone PowerShell 5.1 updater for an
existing `Mods/GameFeatures/UphillSliding` plugin. It downloads pinned and hashed
source files, backs up the replaced files and existing archives, and then calls
Alpakit. It does not alter other mods, feature assets, game installs or server
containers. Close Unreal Editor and Satisfactory first.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Prepare-Release.ps1 -Build
```

The default build includes Windows clients (Steam and Epic) plus Windows and
Linux dedicated servers. `-CheckOnly` performs prerequisites and payload checks
without changing project files. Omit `-Build` to only apply the source update.
`-WindowsOnly -Build` deliberately omits Linux and is insufficient for Linux testing.
Specify `-ProjectRoot` and `-EngineRoot` if your paths differ.

Expected outputs under `Saved/ArchivedPlugins/UphillSliding/`:

| Archive | Contents | Use |
| --- | --- | --- |
| `UphillSliding.zip` | Windows, WindowsServer, LinuxServer directories | Multi-platform distribution after validation |
| `UphillSliding-Windows.zip` | Windows client plugin | Steam/Epic client and listen host |
| `UphillSliding-WindowsServer.zip` | Windows server plugin | Windows dedicated server |
| `UphillSliding-LinuxServer.zip` | Linux server plugin | Linux x86_64 dedicated server |

The release script verifies 1.1.0 metadata, required-on-remote policy, game-feature
marking, native module manifests and binary presence for each selected target.
A build/verification failure is not a distributable package. Retain the full log.

## Set up the first Docker test

1. Confirm the vanilla client can join the server. Record both game build numbers.
2. Use Satisfactory Mod Manager on the client and SMM's server management or
   ficsit-cli for the server to install a compatible SML version (3.12.x for this
   project). Keep the initial profile minimal. Follow the
   [official dedicated-server instructions](https://docs.ficsit.app/satisfactory-modding/latest/ForUsers/DedicatedServerSetup.html).
3. Before selecting a Docker destination, inspect the container image, game path
   and mounts. A save-only mount may not preserve installed mods when the
   container is recreated. Do not assume `/config` is the game directory.
4. Stop the game and server before copying the prototype. Install the Windows
   platform plugin on the client and the LinuxServer platform plugin on Linux.
   A staged `GameFeature: true` plugin belongs at
   `<game root>/FactoryGame/Mods/GameFeatures/UphillSliding/`; its descriptor must
   be directly inside that directory. Do not nest `LinuxServer/` or `Windows/`
   inside the plugin. The individual platform archives already have the right
   plugin-root layout; the combined archive does not.
5. Ensure readable file permissions for the server's container user. Keep the
   same beta package on both sides. Do not reapply an SMM profile that replaces
   the manually installed development package with stable 1.0.0.
6. Start the server and client. Both logs must show `Uphill Sliding loaded (client/server movement rules).`
   for 1.1.0 (`Uphill Sliding multiplayer prototype loaded` for the tested beta).
   Join the new test save.

Exact copy commands depend on the actual Docker paths and container lifecycle.
They should be prepared after inspecting the new environment.

## Historical beta installation tools

The `Tools/*Prototype*` installers and `Prepare-Multiplayer.ps1` are pinned to
1.1.0-beta.1 for reproducing the recorded tests; they do not install the final
1.1.0 release. Use Mod Manager for published releases.

`Tools/Install-WindowsServer-Prototype.ps1` accepts a plugin-root
`UphillSliding-WindowsServer.zip` and a dedicated game root containing
`FactoryServer.exe`. Stop the server first. The script checks beta metadata,
WindowsServer native manifests/DLLs and cooked packages. If SML is absent, it
installs the official SML 3.12.0 WindowsServer release with a pinned SHA256;
an existing SML installation must match this test version and server target.
Staging and previous-plugin backups stay outside `FactoryGame/Mods`. It does
not change other mods or automatically start or terminate the server.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-WindowsServer-Prototype.ps1 -ArchivePath D:\SteamCMD\UphillSliding-WindowsServer.zip -GameRoot D:\SteamCMD\GameServers\Satisfactory
```

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
| Client lacks beta / server lacks beta / wrong version | SML rejects incompatible connections |
| Singleplayer regression | Previous uphill behavior still works |

Complete the remaining acceptance tests on Windows and Linux dedicated servers,
then repeat on a listen server, testing both host and joining player. Dedicated
server success alone does not validate listen-host and guest behavior.

## Validation status

| Check | Result |
| --- | --- |
| Actual source against mock engine/SML headers | 47 scenarios passed |
| Actual source with `UE_SERVER=1` against mocks | 47 scenarios passed; hooks active |
| Editor build against minimal mock core headers | Passed; movement hooks excluded |
| Real Windows clients (Epic and Steam), Shipping | Both builds passed; Epic client join/uphill comparison passed by author report 2026-10-09; Steam runtime pending |
| Real Windows dedicated, Shipping | Build/archive checks, Windows Server 2025 startup, Epic client join and first uphill comparison passed by author report 2026-10-09; remaining acceptance tests pending |
| Real Linux dedicated x86_64, Shipping | Build, Docker startup, Epic client join and first uphill comparison passed 2026-10-09; remaining acceptance tests pending |
| Real listen-server host and guest | Pending |
| Network correction/ping tests | Pending |
| Final 1.1.0 real-engine build and package checks | Passed 2026-10-09: Windows, WindowsServer and LinuxServer; final Epic Windows client singleplayer uphill-sliding smoke test passed by author report |

The author supplied the complete Windows Alpakit log: `BUILD SUCCESSFUL`,
AutomationTool exit code 0, and successful archive verification for Windows,
WindowsServer and LinuxServer. Build duration was 11 minutes 8 seconds.
The PowerShell updater executed successfully on the author's Windows machine.

Combined `UphillSliding.zip` SHA256 reported by the build script:
`21833a5d20639e8107f8323c03109c8ccdfd298aef117e46c743d6505f7efd79`.

The historical beta artifacts were not supplied for independent binary inspection.
The supplied Linux Docker log confirms native module initialization with
`Uphill Sliding multiplayer prototype loaded (client/server movement rules).`,
SML 3.12.0, beta 1.1.0-beta.1 and the feature transitioning to `Active`. The
container remained running with restart count 0 and exit code 0. This test profile
contains SML plus the manually installed beta; SmartFoundations is not installed.
Startup emitted localization and primary-asset warnings before the successful
`Active` transition.

The author installed the matching Windows beta, joined the Linux server and
reported that uphill sliding worked. For the comparison, the server plugin was
moved outside `FactoryGame/Mods`. Pausing the client mod through Mod Manager also
left that client without SML, so server SML was subsequently moved outside the
Mods directory to permit a vanilla connection. In the comparison session, the
author reported that even a slight uphill slope immediately stopped movement
again. This supports the intended effect in this Epic-client/Linux-server test.
The movement result is a manual author report, not an independently inspected
client log, video or network trace. Two simultaneous players, systematic braking,
collision and respawn checks, and measured correction/latency tests are pending.

The Windows Server 2025 test used game build 502094, SML 3.12.0 and beta
1.1.0-beta.1. The supplied vanilla startup log showed successful initialization
and listeners on 7777 and 8888. The author joined and confirmed vanilla uphill
sliding was not possible. The Windows dedicated installer then validated and
installed the WindowsServer beta and SML. After client reactivation instructions,
the author reported that everything worked when asked about retained uphill
speed, jitter and position resets. No modded Windows server/client log or network
trace was supplied for independent analysis; this is an initial manual test.

Mock tests establish role routing and algorithm regression behavior. They do not
establish real packet prediction or multiplayer compatibility. The real Linux
startup and manual comparisons on both dedicated platforms add evidence for
initial dedicated-server operation; the remaining acceptance tests and listen
host/guest sessions are still pending.
Only update the compatibility claims after the corresponding real tests pass.

## Final 1.1.0 packaging

The author supplied the complete final release build log on 2026-10-09. The
pinned source revision was `4d829ac3ec3a28909f95b23ea50f932c49bafaf0` and
version 1.1.0. Alpakit reported `BUILD SUCCESSFUL`, AutomationTool exit code 0,
and a duration of 2 minutes 4 seconds. The release updater verified 1.1.0
metadata, native modules and cooked packages for Windows, WindowsServer and
LinuxServer; all three platform archives were present.

Reported combined `UphillSliding.zip` SHA256:
`ca3d3fd80aef764485ef6080c122b787aa865279adcafd8c5678cd3b8ea2b466`.

The author uploaded the combined final archive on 2026-10-09. Independent
inspection confirmed the exact reported SHA256, 38,489,596-byte size, ZIP CRCs,
safe entry paths, all three 1.1.0 descriptors, matching SML module manifests,
x86_64 Windows PE DLLs and Linux ELF shared library, and cooked packages.
The GitHub release attachment was checked against the same SHA256 and size.
The author then confirmed successful uphill sliding in singleplayer with the
installed final 1.1.0 Epic Windows client. Recorded dedicated runtime tests still
used beta 1.1.0-beta.1; dedicated final-package retesting and listen co-op remain
separate outstanding checks. `Tools/Install-Windows-Release.ps1` installs the
final Windows client archive, requiring SML and a closed game, with staging and
backup outside the Mods directory.

## ficsit metadata correction

The initial 1.1.0 archive was rejected by ficsit.app because its numeric
`Version` was 2 while `SemVersion` was 1.1.0. The descriptor now uses Version 1,
matching SemVersion's major component. The release ZIP was repaired without
recompiling: only the three platform descriptors change, and every other entry
is verified byte-identical to the original final archive. The earlier SHA256
above describes that original archive, before this metadata correction.
`Prepare-Release.ps1` now pins the corrected source and validates this rule;
future builds therefore retain the corrected metadata.

## Rollback

Source backups are placed alongside the project in an
`UphillSliding-Multiplayer-Backup-*` directory. Restore the listed plugin files
and the archived packages if necessary. For playtesting, stop client/server and
remove only the beta plugin, then restore the previous package or return both
sides to the baseline profile. The mod adds no save content.
