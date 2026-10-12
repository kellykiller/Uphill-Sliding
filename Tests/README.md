# Regression tests

Run `bash Tests/run-tests.sh` with g++ (C++20) and Python 3 installed.
The runner uses `-Wall -Wextra -Werror`, exercises client and `UE_SERVER`
builds both with and without `-DNDEBUG`, and checks editor exclusion.
Expectations remain active with `NDEBUG`; an intentional failing expectation
must terminate every regression binary with a nonzero exit status.
Scenario totals are counted automatically after each successful scenario.

The tests compile the actual mod implementation against small engine/SML stubs.
They cover eligibility gates, network roles, braking, direction limits, original
call counts, temporary angle restoration, hook cleanup and deterministic replay
with identical supplied state. Descriptor metadata is also checked generically.

These tests do **not** validate actual FactoryGame headers, native ABI, packaging,
UE collision physics, saved moves, replication, packets or latency. A real
Alpakit build and the in-game checks in [TESTING.md](../TESTING.md) are required.
