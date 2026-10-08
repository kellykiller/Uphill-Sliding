# Changelog

## 1.1.0-beta.1 — multiplayer prototype (unreleased)

- Run the same uphill sliding rules for owning-client prediction and server authority.
- Include remote players on listen servers and dedicated servers.
- Leave simulated client proxies to standard replicated movement.
- Enable Windows client, Windows server and Linux server packaging.
- Require the identical beta version on the remote side.
- Remove the local enable toggle so client and server rules cannot be switched independently.
- Add role, paired input/state and replay checks using mock engine headers.

Real engine builds and multiplayer sessions are pending.

## 1.0.0 — 2026-10-07

First release of **Uphill Sliding**.

- Allow sliding on walkable uphill slopes in standalone singleplayer.
- Preserve horizontal momentum while retaining normal braking and steering.
- Keep the game's existing slide-jump boosts and downhill acceleration.
