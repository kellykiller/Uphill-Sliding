# Regression checks

Run `bash Tests/run-tests.sh` with Python 3 and a C++20-capable g++.
The tests compile the actual mod source against small mock engine/SML headers.
They check movement gates, original-call forwarding, private member access,
angle restoration, speed retention, hook cleanup and editor/server exclusions.
These mocks do not reproduce Unreal collision physics or SML hook installation.

The 1.0.0 movement source was also compiled with the CSS engine by the author.
