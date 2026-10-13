# How uphill sliding works

The same four hooks run on the owning client's autonomous proxy (prediction and
re-evaluation) and on authority-controlled player characters, including remote
players on dedicated and listen servers. Client simulated proxies are excluded;
other players are displayed through normal replicated movement.

The calculation uses crouch input, acceleration, velocity, sliding state and the
walkable floor. It adds no persistent movement state or custom RPCs. FactoryGame
already declares saved slide state and compressed-flag handling in its movement
implementation. This makes using the existing movement pipeline a reasonable
first implementation; real server corrections must still be measured.

The normal collision solver and position validation stay enabled. Walkability,
reverse-input braking, sharp-turn checks, and original slide eligibility remain.
The former local Enabled console variable is removed to prevent divergent rules.
There are no player configuration or diagnostic console options in 1.1.1.

`RequiredOnRemote` is true. `RemoteVersionRange` is omitted, so SML requires the
exact same mod version on both sides. Do not mix 1.1.1 with 1.1.0, 1.0.0 or historical beta packages in a session.

[Confirmed test results](../TESTING.md) · [Release history](../RELEASES.md)
