# Release history

Uphill Sliding 1.1.1 supports matching movement rules on clients and servers.
Install the same mod version on every client and server with compatible SML.
For directly hosted co-op, both host and guests need the mod; that session mode
has not yet been tested.

- [Build/setup and archive instructions](BUILDING.md)
- [Confirmed results, remaining checks and acceptance tests](TESTING.md)
- [Complete historical beta/build record](Docs/History/1.1.0-validation.md)

## Versions

- **1.0.0:** standalone singleplayer only.
- **1.1.0 (2026-10-09):** multiplayer support and Windows/Linux dedicated packages.
  Final release tested on both dedicated platforms with the Epic Windows client:
  joining and uphill speed retention passed, with no noticeable jitter or resets.
- **1.1.1 (2026-10-12):** consistent native module naming and repository cleanup.
  Gameplay unchanged. Native builds and Alpakit packaging passed. The author
  confirmed successful Windows dedicated and Linux Docker dedicated functional
  tests with the Epic Windows client on 2026-10-12 after the game update.
  Combined archive inspection passed. The 1.1.1 singleplayer test also passed on
  2026-10-12 with Epic Windows: uphill sliding worked with no reported issues.
  All three sessions used Satisfactory 1.2.4.1 (513885) and SML 3.12.0.
  These are manual author confirmations, not independent recordings.

Keep these version-specific results separate. Passing 1.1.0 runtime tests does
not validate a newly compiled 1.1.1 package.
