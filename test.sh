#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
sdk_path="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
build_dir="$project_dir/.build/manual"
module_cache="$project_dir/.build/module-cache"

mkdir -p "$build_dir" "$module_cache"
swiftc -sdk "$sdk_path" -module-cache-path "$module_cache" \
  -emit-library -emit-module -enable-testing -module-name MacBookDuoCore \
  "$project_dir"/Sources/MacBookDuoCore/*.swift \
  -o "$build_dir/libMacBookDuoCore.dylib"
swiftc -sdk "$sdk_path" -module-cache-path "$module_cache" \
  -I "$build_dir" -L "$build_dir" -lMacBookDuoCore \
  "$project_dir/Tests/TestRunner.swift" -o "$build_dir/CoreTests"
DYLD_LIBRARY_PATH="$build_dir" "$build_dir/CoreTests"
