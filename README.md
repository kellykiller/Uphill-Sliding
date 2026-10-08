# Uphill Sliding

<img src="Media/UphillSliding.png" alt="Uphill Sliding" width="640">

Keep your speed when the terrain turns uphill.

**Uphill Sliding** lets you continue sliding across uphill slopes in Satisfactory
without abruptly losing your horizontal momentum. Carry the speed you built on
a downhill stretch into the next incline, and keep chaining the game's existing
slide jumps across uneven terrain.

## Features

- Slide uphill on surfaces the game considers walkable.
- Preserve horizontal momentum when an incline would normally slow your slide.
- Keep normal braking: release crouch or apply reverse movement input.
- Use the game's normal crouch and jump controls; no unlocks are required.

The game's existing slide-jump boosts and downhill acceleration stay unchanged.

## Multiplayer prototype — 1.1.0-beta.1

This development branch enables the movement rules on the owning client and on
server authority, including remote players on dedicated and listen servers.
Install **the same beta version on every client and the server**.

Build targets: Windows client (Steam and Epic), Windows dedicated server and
Linux x86_64 dedicated server. The platform builds and real network movement
still need testing; these are intended targets, not verified compatibility claims.
See [MULTIPLAYER.md](MULTIPLAYER.md) for setup, test cases and current results.

Version [1.0.0](https://github.com/kellykiller/Uphill-Sliding/releases/tag/v1.0.0)
remains the tested Windows singleplayer release. Its movement changes are inactive
in multiplayer. Development uses **UE 5.6.1-CSS** and **SML 3.12.x**.

## Source code

This repository contains the mod plugin, including its C++ source and assets.
For development, place it in `Mods/GameFeatures/UphillSliding` inside a compatible
Satisfactory Modding project using **Unreal Engine 5.6.1-CSS** and matching SML headers.

## Bug reports

[Open an issue](https://github.com/kellykiller/Uphill-Sliding/issues) with your game
version and a short description of how to reproduce the problem.

---
Created by **Kellykiller** with assistance from OpenAI ChatGPT/Codex for code,
artwork and documentation.
