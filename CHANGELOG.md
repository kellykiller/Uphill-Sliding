# Changelog

## 1.1.1 — unreleased

- Rename the native module, source paths, class and logging to UphillSliding.
- Preserve all existing movement conditions, network routing, thresholds and hook cleanup.
- Add readable regression tests that remain active with NDEBUG and minimal CI.
- Unify preparation scripts, remove personal paths and archive historical tools.
- Add MIT licensing and split build instructions from documented test results.
- Record confirmed final 1.1.0 dedicated-server tests accurately.

Real Alpakit builds and renewed singleplayer/dedicated tests are required before
publishing 1.1.1. Old releases, tags and asset hashes remain unchanged.

## 1.1.0 — 2026-10-09

- Add multiplayer support using matching uphill sliding rules on clients and the server.
- Add packages for Windows and Linux dedicated servers alongside Windows clients.
- Require the same mod version on every client and server.
- Keep the existing uphill momentum, braking, steering and walkable-surface rules.
- Remove diagnostic console options and per-slide debug logging.
- Correct the plugin descriptor's numeric Version to match SemVersion major 1
  for ficsit.app uploads; native binaries and gameplay are unchanged.

Final 1.1.0 tests passed on **Windows dedicated and Linux Docker** with the
**Epic Windows client** on **2026-10-09**, as explicitly confirmed by the author.
Joining and uphill speed retention worked, with no noticeable jitter or position
resets. The final Epic client also passed the singleplayer uphill-sliding smoke test.
Real builds and archive checks passed for all three platform packages.
Directly hosted co-op, Steam runtime and systematic latency/packet-loss testing
remain untested. See [TESTING.md](TESTING.md) for the scope of these reports.

## 1.0.0 — 2026-10-07

First release of **Uphill Sliding**.

- Allow sliding on walkable uphill slopes in standalone singleplayer.
- Preserve horizontal momentum while retaining normal braking and steering.
- Keep the game's existing slide-jump boosts and downhill acceleration.
