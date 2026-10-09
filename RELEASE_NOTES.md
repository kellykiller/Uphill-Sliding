# Uphill Sliding 1.1.0

Keep your speed when the terrain turns uphill — now in multiplayer.

Slide across walkable uphill slopes without abruptly losing horizontal momentum.
Carry your downhill speed into the next incline and chain Satisfactory's existing
slide jumps across uneven terrain.

## What's new

- Multiplayer movement rules on clients and the server.
- Windows and Linux dedicated-server packages.
- Matching mod versions required on every client and server.
- Normal crouch/jump controls, braking and steering; no configuration needed.

Existing slide-jump boosts and downhill acceleration remain unchanged.

## Compatibility

Initial join and uphill comparison tests passed on **Windows and Linux dedicated
servers** with the **Epic Games Windows client**, Satisfactory **1.2.4.0 (502094)**
and **SML 3.12.0**, using the 1.1.0 beta. The final release retains those movement
rules and removes diagnostic logging. The final **1.1.0 Epic Windows client**
also passed the author's singleplayer uphill-sliding smoke test.

**Directly hosted co-op is supported by the code but has not been tested.** Steam
client builds passed; Steam runtime testing and broader two-player, latency,
collision and respawn checks remain open.

Install the **same version** on all clients and the server. For co-op, both host
and guests need the mod. Use compatible SML versions.

The final 1.1.0 build and archive checks passed for Windows, WindowsServer and
LinuxServer. The combined `UphillSliding.zip` contains all three platform packages.
The attached archive was independently checked and matches the final build:
SHA-256 `ca3d3fd80aef764485ef6080c122b787aa865279adcafd8c5678cd3b8ea2b466`.

[Mod page](https://ficsit.app/mod/FKXKumYqzkUAhw) ·
[Report a bug](https://github.com/kellykiller/Uphill-Sliding/issues) ·
[Test results](https://github.com/kellykiller/Uphill-Sliding/blob/main/MULTIPLAYER.md)
