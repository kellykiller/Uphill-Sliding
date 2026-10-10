#!/usr/bin/env bash
set -euo pipefail
test_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
test_build_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_build_dir"' EXIT
common=(-std=c++20 -Wall -Wextra -Werror -I"$test_dir/stubs" -I"$test_dir/../Source/UphillSliding/Private")
for variant in client client-ndebug server server-ndebug; do
    flags=()
    [[ "$variant" != server* ]] || flags+=(-DUE_SERVER=1)
    [[ "$variant" != *ndebug ]] || flags+=(-DNDEBUG)
    g++ "${common[@]}" "${flags[@]}" "$test_dir/Regression.cpp" -o "$test_build_dir/$variant"
    "$test_build_dir/$variant"
    if "$test_build_dir/$variant" --verify-failure >"$test_build_dir/failure.log" 2>&1; then
        echo "FAIL: expectation did not stop $variant" >&2
        exit 1
    fi
    echo "PASS expectation failure check: $variant"
done
mkdir -p "$test_build_dir/guard-stubs/Modules"
cp "$test_dir/stubs/CoreMinimal.h" "$test_build_dir/guard-stubs/"
cp "$test_dir/stubs/Modules/ModuleManager.h" "$test_build_dir/guard-stubs/Modules/"
guards=(-std=c++20 -Wall -Wextra -Werror -I"$test_build_dir/guard-stubs" -I"$test_dir/../Source/UphillSliding/Private")
g++ "${guards[@]}" -DWITH_EDITOR=1 "$test_dir/CompileGuards.cpp" -o "$test_build_dir/editor"
"$test_build_dir/editor"
python3 "$test_dir/check-metadata.py"
echo "PASS editor exclusion and active dedicated-server hooks (mock engine/SML)."
