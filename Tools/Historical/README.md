# Historical tools — not for current releases

These files retain reproducibility of the 1.1.0-beta.1 development packages.
Their legacy `SlideMomentum` module names are intentional: those binaries were
built before the native module rename. `Beta-Pins.json` retains the immutable
source revision and original payload hashes.

`Prepare-Multiplayer.ps1` is a thin wrapper over the current shared updater;
use a full repository checkout and explicit ProjectRoot/EngineRoot parameters.
`Install-*Prototype*` accepts historical beta packages only.
`Repair-Release-Metadata.py` is an archived, completed one-off repair utility.
**Do not execute it against existing public releases or rerun release repairs.**
Current builds and installations use the scripts in the parent `Tools` directory.
