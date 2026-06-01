#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRODUCT="NativeMacADE"
APP_NAME="Atelier"
APP_BUNDLE_NAME="Atelier"
APP_ICON_NAME="AppIcon"
BUNDLE_ID="com.matheusbbarni.Atelier"
MIN_MACOS_VERSION="15.0"
ICON_SOURCE="$ROOT_DIR/Sources/NativeMacADE/Resources/AppIcon.png"
APP_VERSION="${APP_VERSION:-0.1.1}"
APP_BUILD="${APP_BUILD:-1}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
MODE="${1:-run}"

if [[ $# -gt 0 ]]; then
  shift
fi

cd "$ROOT_DIR"

compile_app_icon_assets() {
  local source_png="$1"
  local output_dir="$2"
  local temp_dir asset_catalog_dir appiconset_dir partial_info_plist

  temp_dir="$(mktemp -d)"
  asset_catalog_dir="$temp_dir/Assets.xcassets"
  appiconset_dir="$asset_catalog_dir/${APP_ICON_NAME}.appiconset"
  partial_info_plist="$temp_dir/asset-catalog-info.plist"
  mkdir -p "$appiconset_dir"

  cat > "$appiconset_dir/Contents.json" <<EOF
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF

  sips -z 16 16 "$source_png" --out "$appiconset_dir/icon_16x16.png" >/dev/null
  sips -z 32 32 "$source_png" --out "$appiconset_dir/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$source_png" --out "$appiconset_dir/icon_32x32.png" >/dev/null
  sips -z 64 64 "$source_png" --out "$appiconset_dir/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$source_png" --out "$appiconset_dir/icon_128x128.png" >/dev/null
  sips -z 256 256 "$source_png" --out "$appiconset_dir/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$source_png" --out "$appiconset_dir/icon_256x256.png" >/dev/null
  sips -z 512 512 "$source_png" --out "$appiconset_dir/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$source_png" --out "$appiconset_dir/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$source_png" --out "$appiconset_dir/icon_512x512@2x.png" >/dev/null

  xcrun actool \
    --platform macosx \
    --minimum-deployment-target "$MIN_MACOS_VERSION" \
    --app-icon "$APP_ICON_NAME" \
    --output-partial-info-plist "$partial_info_plist" \
    --compile "$output_dir" \
    "$asset_catalog_dir" >/dev/null

  rm -rf "$temp_dir"
}

sign_app_bundle() {
  local app_bundle="$1"
  local codesign_args=(--force --sign "$CODESIGN_IDENTITY")

  if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
    codesign_args+=(--options runtime)
  fi

  codesign "${codesign_args[@]}" "$app_bundle" >&2
  codesign --verify --deep --strict --verbose=2 "$app_bundle" >&2
}

build_app_bundle() {
  local build_args=()
  if [[ $# -gt 0 ]]; then
    build_args=("$@")
  fi

  if [[ ${#build_args[@]} -gt 0 ]]; then
    swift build --product "$PRODUCT" "${build_args[@]}" >&2
  else
    swift build --product "$PRODUCT" >&2
  fi

  local bin_path app_bundle contents_dir macos_dir resources_dir executable_path resource_bundle_path
  if [[ ${#build_args[@]} -gt 0 ]]; then
    bin_path="$(swift build --show-bin-path "${build_args[@]}")"
  else
    bin_path="$(swift build --show-bin-path)"
  fi
  executable_path="$bin_path/$PRODUCT"
  resource_bundle_path="$(find "$bin_path" -maxdepth 1 -type d -name "${PRODUCT}_*.bundle" | head -n 1)"

  app_bundle="$bin_path/$APP_BUNDLE_NAME.app"
  contents_dir="$app_bundle/Contents"
  macos_dir="$contents_dir/MacOS"
  resources_dir="$contents_dir/Resources"

  rm -rf "$app_bundle"
  mkdir -p "$macos_dir" "$resources_dir"

  cp "$executable_path" "$macos_dir/$PRODUCT"

  if [[ -n "$resource_bundle_path" ]]; then
    cp -R "$resource_bundle_path" "$resources_dir/"
  fi

  if [[ -f "$ICON_SOURCE" ]]; then
    compile_app_icon_assets "$ICON_SOURCE" "$resources_dir"
  fi

  cat > "$contents_dir/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT</string>
  <key>CFBundleIconFile</key>
  <string>$APP_ICON_NAME</string>
  <key>CFBundleIconName</key>
  <string>$APP_ICON_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_MACOS_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

  sign_app_bundle "$app_bundle"

  echo "$app_bundle"
}

case "$MODE" in
  run)
    app_bundle="$(build_app_bundle)"
    open -n "$app_bundle" --args "$@"
    ;;
  build)
    exec swift build --product "$PRODUCT" "$@"
    ;;
  bundle)
    build_app_bundle "$@"
    ;;
  test)
    exec swift test "$@"
    ;;
  *)
    cat <<'EOF'
Usage: ./scripts/run.sh [run|build|bundle|test] [swift arguments...]

  run    Build a .app bundle and launch Atelier (default)
  build  Build Atelier without launching it
  bundle Build the .app bundle and print its path
  test   Run the Swift test suite
EOF
    exit 1
    ;;
esac
