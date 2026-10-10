# Uphill Sliding 1.1.1 — draft, unreleased

Internal naming and repository cleanup. Uphill sliding, braking, steering,
slide-jump behavior and multiplayer movement rules are unchanged.

- Native module and log names now consistently use UphillSliding.
- Regression checks remain active in release-style test builds; CI added.
- Preparation scripts consolidated, historical beta tools isolated, MIT license added.
- Documentation records final 1.1.0 Windows/Linux dedicated tests correctly.

The module rename changes native binary names. Build fresh Windows, WindowsServer
and LinuxServer packages and repeat singleplayer/dedicated acceptance checks
before tagging or uploading 1.1.1. Install the same new version on all clients
and the server. Existing 1.0.0 and 1.1.0 assets and tags remain untouched.

Final **1.1.0** was tested on **2026-10-09** on Windows dedicated and Linux Docker
with an Epic Windows client: joining and uphill speed retention passed, with
no noticeable jitter or position resets. Those reports do not validate 1.1.1.
Directly hosted co-op and Steam runtime remain untested.

[Build instructions](BUILDING.md) · [Test status](TESTING.md) ·
[Report a bug](https://github.com/kellykiller/Uphill-Sliding/issues)
