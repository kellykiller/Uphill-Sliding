# Regression tests

Run `bash Tests/run-tests.sh` with g++ (C++20) and Python 3 installed.
The runner uses `-Wall -Wextra -Werror`, exercises client and `UE_SERVER`
builds both with and without `-DNDEBUG`, and checks editor exclusion.
Expectations remain active with `NDEBUG`; an intentional failing expectation
must terminate every regression binary with a nonzero exit status.
Scenario totals are counted automatically after each successful scenario.

The default local runner also verifies release build-input hashes. In CI,
`UPHILL_PIN_CHECK_SEPARATE_JOB=1` skips only that hash check in the regression
job because the dedicated release-pins job runs it with full Git history.
The separate metadata workflow was removed: `check-metadata.py` already runs
once in the regression runner, so metadata validation stays available locally.
CI runs on pushes to main and pull requests, rather than twice on PR branches.
All Tools PowerShell files are parsed in both pwsh and Windows PowerShell 5.1;
the parser does not execute installers or invoke an Engine build.

The tests compile the actual mod implementation against small engine/SML stubs.
They cover eligibility gates, network roles, braking, direction limits, original
call counts, temporary angle restoration, hook cleanup and deterministic replay
with identical supplied state. Descriptor metadata is also checked generically.

These tests do **not** validate actual FactoryGame headers, native ABI, packaging,
UE collision physics, saved moves, replication, packets or latency. A real
Alpakit build and the in-game checks in [TESTING.md](../TESTING.md) are required.
