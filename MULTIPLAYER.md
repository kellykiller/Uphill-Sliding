# Multiplayer development — 1.1.0-beta.1

The source changes are ready for a first real-engine build and network test.
The stable 1.0.0 release stays singleplayer only.

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
There are no player configuration options. Diagnostic logging defaults to off.

`RequiredOnRemote` is true. `RemoteVersionRange` is omitted, so SML requires the
exact same mod version on both sides. Do not mix this beta with 1.0.0.

## Build on Windows

Use the existing matching SML starter project and UE 5.6.1-CSS installation.
Install Epic's **v25 clang-18.1.0-based Linux cross-compilation toolchain** on the
Windows development machine, then open a new PowerShell window.

Official downloads and setup:
- [Satisfactory modding requirements](https://docs.ficsit.app/satisfactory-modding/latest/Development/BeginnersGuide/dependencies.html#_clang_toolchain_for_linux_dedicated_server_support)
- [Epic toolchain table for UE 5.6](https://dev.epicgames.com/documentation/en-us/unreal-engine/linux-development-requirements-for-unreal-engine?application_version=5.6)

`Tools/Prepare-Multiplayer.ps1` is a standalone PowerShell 5.1 updater for an
existing `Mods/GameFeatures/UphillSliding` plugin. It downloads pinned and hashed
source files, backs up the replaced files and existing archives, and then calls
Alpakit. It does not alter other mods, feature assets, game installs or server
containers. Close Unreal Editor and Satisfactory first.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Prepare-Multiplayer.ps1 -Build
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

The script verifies beta metadata, required-on-remote policy, game-feature
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
6. Start the server and client. Both logs must show `Uphill Sliding multiplayer
   prototype loaded`. Join the new test save.

Exact copy commands depend on the actual Docker paths and container lifecycle.
They should be prepared after inspecting the new environment.

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

Then repeat on a Windows dedicated server and a listen server, testing both host
and joining player. Linux success alone does not validate those session types.

## Validation status

| Check | Result |
| --- | --- |
| Actual source against mock engine/SML headers | 47 scenarios passed |
| Actual source with `UE_SERVER=1` against mocks | 47 scenarios passed; hooks active |
| Editor build against minimal mock core headers | Passed; movement hooks excluded |
| Real Windows client build and game test | Pending |
| Real Windows dedicated build and session | Pending |
| Real Linux dedicated build and Docker session | Pending |
| Real listen-server host and guest | Pending |
| Network correction/ping tests | Pending |

Mock tests establish role routing and algorithm regression behavior. They do not
establish real packet prediction, Linux ABI hooking or multiplayer compatibility.
Only update the compatibility claims after the corresponding real tests pass.

## Rollback

Source backups are placed alongside the project in an
`UphillSliding-Multiplayer-Backup-*` directory. Restore the listed plugin files
and the archived packages if necessary. For playtesting, stop client/server and
remove only the beta plugin, then restore the previous package or return both
sides to the baseline profile. The mod adds no save content.
