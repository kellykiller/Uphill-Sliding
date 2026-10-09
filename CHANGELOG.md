# Changelog

## 1.1.0 — 2026-10-09

- Add multiplayer support using matching uphill sliding rules on clients and the server.
- Add packages for Windows and Linux dedicated servers alongside Windows clients.
- Require the same mod version on every client and server.
- Keep the existing uphill momentum, braking, steering and walkable-surface rules.
- Remove diagnostic console options and per-slide debug logging.
- Correct the plugin descriptor's numeric Version to match SemVersion major 1
  for ficsit.app uploads; native binaries and gameplay are unchanged.

Initial join and uphill comparison tests passed on Windows and Linux dedicated
servers with the Epic Windows client using 1.1.0-beta.1. Directly hosted co-op is
supported by the code but has not been tested. Final 1.1.0 builds and archive checks passed for all three platforms.
The final Epic Windows client passed the author's singleplayer uphill-sliding
smoke test. The combined release archive was independently inspected and attached.

## 1.0.0 — 2026-10-07

First release of **Uphill Sliding**.

- Allow sliding on walkable uphill slopes in standalone singleplayer.
- Preserve horizontal momentum while retaining normal braking and steering.
- Keep the game's existing slide-jump boosts and downhill acceleration.
