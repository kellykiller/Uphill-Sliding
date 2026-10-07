#!/usr/bin/env bash
set -euo pipefail
test_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
test_build_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_build_dir"' EXIT
common=(-std=c++20 -Wall -Wextra -Werror -I"$test_dir/stubs" -I"$test_dir/../Source/SlideMomentum/Public")
g++ "${common[@]}" "$test_dir/Regression.cpp" -o "$test_build_dir/regression"
"$test_build_dir/regression"
mkdir -p "$test_build_dir/guard-stubs/Modules"
cp "$test_dir/stubs/CoreMinimal.h" "$test_build_dir/guard-stubs/"
cp "$test_dir/stubs/Modules/ModuleManager.h" "$test_build_dir/guard-stubs/Modules/"
guards=(-std=c++20 -Wall -Wextra -Werror -I"$test_build_dir/guard-stubs" -I"$test_dir/../Source/SlideMomentum/Public")
g++ "${guards[@]}" -DWITH_EDITOR=1 "$test_dir/CompileGuards.cpp" -o "$test_build_dir/editor"
g++ "${guards[@]}" -DUE_SERVER=1 "$test_dir/CompileGuards.cpp" -o "$test_build_dir/server"
"$test_build_dir/editor"
"$test_build_dir/server"
echo "PASS editor and dedicated-server compile guards (mock core headers)."
