# Regression checks

Run `bash Tests/run-tests.sh` with a C++20-capable g++.
The tests compile the actual mod source against small mock engine/SML headers.

47 scenarios run in both a normal game build and a `UE_SERVER=1` build:
movement gates, server authority for remote players, owning-client prediction,
simulated proxy exclusion, original-call forwarding, private member access,
angle restoration, speed retention, braking and hook cleanup. Seven paired
client/server input sequences compare all four hook decisions and velocities,
including repeat evaluation from a copied pre-move state.

The editor exclusion compiles separately without FactoryGame/SML hook headers.

These mocks do not reproduce real UE saved moves, network transport, collision
physics or native hook installation. They cannot establish multiplayer support
or binary compatibility. Real platform builds and network tests are tracked in
[MULTIPLAYER.md](../MULTIPLAYER.md).
