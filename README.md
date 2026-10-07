# SlideMomentum

A Satisfactory mod that lets you slide uphill while preserving horizontal momentum.

## Features

- Continue sliding across walkable uphill slopes.
- Retain horizontal speed during uphill slides instead of losing momentum abruptly.
- Chain the game's existing slide jumps across gentle inclines.
- Release crouch or apply reverse movement input to brake normally.

The mod does not change the game's slide-jump multipliers or downhill acceleration.

## Compatibility

- **Singleplayer only.** Movement changes are enabled only in standalone play.
- **Windows client.**
- Tested in Satisfactory **1.2.4.0, build 502094**, using the **Epic Games** version.
- Satisfactory Mod Loader dependency: **^3.12.0**.
- Multiplayer, dedicated servers, Steam and Experimental have not been tested.

## Usage

The mod is enabled by default. Use the game's normal crouch and jump controls.
No milestone or unlock is required.

Console variables, when a console is available:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SlideMomentum.Enabled` | `1` | Set to `0` to disable the movement changes. |
| `SlideMomentum.Debug` | `0` | Set to `1` to log uphill slide checks and speed corrections. |

## Development

This repository is intended to contain the **SlideMomentum plugin**, not the whole FactoryGame starter project.

Place the plugin in `Mods/GameFeatures/SlideMomentum` inside a compatible Satisfactory Modding starter project. Use the Coffee Stain Unreal Engine **5.6.1-CSS** build and the matching SML development environment.

Build the editor target for development. Package with **Alpakit Release**, selecting **Windows** only for this singleplayer version. The combined `SlideMomentum.zip` is the package intended for upload to ficsit.app; an Alpakit Dev package is for local testing.

## Bug reports

Please [open an issue](https://github.com/kellykiller/SlideMomentum/issues) with your game build, launcher, SML version, installed movement mods, and steps to reproduce the problem.

## AI assistance

OpenAI ChatGPT/Codex assisted with source code, installation scripts, documentation and release text. The author compiled the mod and tested its behavior in the game.

## Release status

The mod has been tested locally. Publication on ficsit.app is being prepared.
