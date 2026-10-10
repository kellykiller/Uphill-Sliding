# Building and development setup

This repository is a mod plugin, not the complete Satisfactory Modding starter
project or the Engine. Use a matching starter project, FactoryGame/SML headers,
Visual Studio toolchain and **Unreal Engine 5.6.1-CSS**.

For Linux dedicated support on a Windows build machine, install Epic's
**v25 clang-18.1.0-based cross-compilation toolchain**, then reopen PowerShell.

- [Satisfactory modding requirements](https://docs.ficsit.app/satisfactory-modding/latest/Development/BeginnersGuide/dependencies.html#_clang_toolchain_for_linux_dedicated_server_support)
- [Epic UE 5.6 toolchain requirements](https://dev.epicgames.com/documentation/en-us/unreal-engine/linux-development-requirements-for-unreal-engine?application_version=5.6)

## Apply the proposed 1.1.1 source update

`Tools/Prepare-Release.ps1` supports Windows PowerShell 5.1. `ProjectRoot` and
`EngineRoot` are mandatory; no personal directory is embedded in the script.
It downloads a pinned source revision and verifies every payload hash before
changing the existing plugin. Run the script from the completed review branch.

```powershell
$projectRoot = "D:\SatisfactoryModding"
$engineRoot = "C:\Program Files\Unreal Engine - CSS"
$toolchainRoot = "C:\UnrealToolchains\v25_clang-18.1.0-rockylinux8"

& .\Tools\Prepare-Release.ps1 -ProjectRoot $projectRoot -EngineRoot $engineRoot -ToolchainRoot $toolchainRoot -CheckOnly
& .\Tools\Prepare-Release.ps1 -ProjectRoot $projectRoot -EngineRoot $engineRoot -ToolchainRoot $toolchainRoot -Build
```

Close Unreal Editor, the game and local dedicated servers before applying.
`-CheckOnly` checks prerequisites and hashes without writing project files or
starting a build. Omit `-Build` to apply source only. `-WindowsOnly -Build` omits
Linux and is insufficient for a complete three-platform release.

The updater backs up the **entire plugin** outside the project, replaces its
module source, and clears only this plugin's `Binaries` and `Intermediate`.
Legacy `Source/SlideMomentum` is removed during migration to `Source/UphillSliding`.
Copy failures restore the plugin backup; build failures keep the updated source
and report the log and previous archives. Existing feature assets, other mods,
game installations and server containers are not updated by this script.
Temporary downloads are removed on exit.

After the native module rename, regenerate IDE project files. PackagePlugin uses
`-nocompileeditor`; build the editor target separately before reopening the editor:

```powershell
$buildScript = Join-Path $engineRoot "Engine\Build\BatchFiles\Build.bat"
$projectPath = Join-Path $projectRoot "FactoryGame.uproject"
& $buildScript -projectfiles "-project=$projectPath" -game -rocket -progress
& $buildScript FactoryEditor Win64 Development "-Project=$projectPath" -WaitMutex
```

A real editor and shipping build must confirm the private header location and
private module dependencies. Broad FactoryGame header dependencies are retained
until actual headers demonstrate which entries can safely be removed.

## Archive outputs

Expected under `Saved/ArchivedPlugins/UphillSliding/`:

| Archive | Contents | Use |
| --- | --- | --- |
| `UphillSliding.zip` | Windows, WindowsServer, LinuxServer directories | Combined distribution after validation |
| `UphillSliding-Windows.zip` | Windows plugin root | Steam/Epic client and listen host |
| `UphillSliding-WindowsServer.zip` | Windows server plugin root | Windows dedicated server |
| `UphillSliding-LinuxServer.zip` | Linux server plugin root | Linux x86_64 dedicated server |

The updater checks version fields, required-on-remote policy, game-feature
metadata, the renamed module manifests, native files and cooked content.
Source descriptors do not contain `GameFeature`; Alpakit inserts it in packaged
descriptors. A failed build or archive check is not a distributable package.
Keep the full build log and complete [TESTING.md](TESTING.md) before publishing.

## Server and client setup for testing

1. Confirm vanilla client/server compatibility and record both game builds.
2. Install compatible SML on all machines with Satisfactory Mod Manager, SMM's
   server management or ficsit-cli. Start with a minimal profile. See the
   [dedicated-server setup documentation](https://docs.ficsit.app/satisfactory-modding/latest/ForUsers/DedicatedServerSetup.html).
3. For Docker, inspect the image, mounts, container user and actual game path
   before choosing a destination. A save-only mount may not preserve installed
   mods after container recreation; `/config` is not necessarily the game root.
4. Stop game/server before installing. Use the platform archive for that machine,
   not the combined ZIP. A staged game-feature plugin belongs at
   `<game root>/FactoryGame/Mods/GameFeatures/UphillSliding/UphillSliding.uplugin`.
   Do not nest `Windows/` or `LinuxServer/` inside the plugin directory.
5. Ensure readable files and traversable directories for the server user. Install
   exactly the same mod version on clients/server. Reapplying a Mod Manager profile
   can replace a manually installed development package with its published version.
6. Start both sides. Logs should include
   `LogUphillSliding: ... Uphill Sliding loaded (client/server movement rules).`
   Join the test save and follow the acceptance checklist.

`Tools/Install-Windows-Release.ps1` installs the **new 1.1.1 Windows platform ZIP**
only. It requires SML, matching descriptor/module metadata and a closed game,
with staging and previous-plugin backup outside `FactoryGame/Mods`.

```powershell
& .\Tools\Install-Windows-Release.ps1 -ArchivePath "D:\Packages\UphillSliding-Windows.zip" -GameRoot "D:\Games\Satisfactory"
```

For dedicated servers, install the matching platform package through the normal
server mod workflow or replace only the stopped server's plugin directory with
that platform ZIP's contents. Inspect the actual paths before copying.

## Historical reproduction and rollback

`Tools/Historical` retains the 1.1.0-beta.1 installers, immutable beta pins and the
completed 1.1.0 metadata repair utility. They are clearly historical and must not
be run against existing public releases. The historical prepare wrapper forwards
to the shared updater using `-Channel HistoricalBeta`; use the whole repo checkout
so its `Beta-Pins.json` is present. Current builds use the default `Release` channel.

The historical WindowsServer installer checks beta DLLs/cooked packages and can
install the official pinned SML 3.12.0 server package. It neither starts/stops that
server nor changes other mods. The historical Linux installer manages its specified
Docker container and keeps existing SML and other mods. Reproduction commands and
original observations remain in [the historical record](Docs/History/1.1.0-validation.md).

To roll back source, close relevant processes and restore the full `Plugin` backup
from `UphillSliding-Release-Backup-*`, then restore the saved archives if needed.
For a runtime comparison, stop both sides and move the mod outside `FactoryGame/Mods`,
restoring matching baseline profiles. SML alone still marks a server as modded;
a vanilla comparison requires matching vanilla installations on both sides.
The mod adds no save content.
