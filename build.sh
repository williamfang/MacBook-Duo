#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h}"
sdk_path="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
build_dir="$project_dir/.build/manual"
app_dir="$project_dir/.build/MacBook Duo.app"
module_cache="$project_dir/.build/module-cache"

"$project_dir/test.sh"
mkdir -p "$build_dir" "$module_cache" "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"

swiftc -sdk "$sdk_path" -module-cache-path "$module_cache" -O -swift-version 5 \
  -emit-library -emit-module -module-name MacBookDuoCore \
  "$project_dir"/Sources/MacBookDuoCore/*.swift \
  -Xlinker -install_name -Xlinker @rpath/libMacBookDuoCore.dylib \
  -o "$build_dir/libMacBookDuoCore.dylib"

swiftc -sdk "$sdk_path" -module-cache-path "$module_cache" -O -swift-version 5 \
  -I "$build_dir" -L "$build_dir" -lMacBookDuoCore \
  -framework AppKit -framework CoreGraphics -framework IOKit -framework MetalKit -framework ScreenCaptureKit \
  "$project_dir"/Sources/MacBookDuo/*.swift \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  -o "$app_dir/Contents/MacOS/MacBookDuo"

mkdir -p "$app_dir/Contents/Frameworks"
cp "$build_dir/libMacBookDuoCore.dylib" "$app_dir/Contents/Frameworks/"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
cp "$project_dir/Sources/MacBookDuo/Shaders.metal" "$app_dir/Contents/Resources/Shaders.metal"
signing_identity="${MACBOOK_DUO_SIGNING_IDENTITY:-}"
if [[ -n "$signing_identity" ]] && security find-identity -v -p codesigning | grep -Fq "$signing_identity"; then
  codesign --force --sign "$signing_identity" --timestamp=none "$app_dir/Contents/Frameworks/libMacBookDuoCore.dylib"
  codesign --force --deep --options runtime --sign "$signing_identity" --timestamp=none "$app_dir"
else
  codesign --force --deep --sign - "$app_dir"
fi
echo "$app_dir"
