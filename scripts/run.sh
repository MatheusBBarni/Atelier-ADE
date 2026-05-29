#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRODUCT="NativeMacADE"
APP_NAME="Atelier"
APP_BUNDLE_NAME="Atelier"
BUNDLE_ID="com.matheusbbarni.Atelier"
MIN_MACOS_VERSION="15.0"
ICON_SOURCE="$ROOT_DIR/Sources/NativeMacADE/Resources/AppIcon.png"
MODE="${1:-run}"

if [[ $# -gt 0 ]]; then
  shift
fi

cd "$ROOT_DIR"

create_icns() {
  local source_png="$1"
  local output_icns="$2"
  local temp_dir
  local iconset_dir

  temp_dir="$(mktemp -d)"
  iconset_dir="$temp_dir/AppIcon.iconset"
  mkdir -p "$iconset_dir"

  sips -z 16 16 "$source_png" --out "$iconset_dir/icon_16x16.png" >/dev/null
  sips -z 32 32 "$source_png" --out "$iconset_dir/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$source_png" --out "$iconset_dir/icon_32x32.png" >/dev/null
  sips -z 64 64 "$source_png" --out "$iconset_dir/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$source_png" --out "$iconset_dir/icon_128x128.png" >/dev/null
  sips -z 256 256 "$source_png" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$source_png" --out "$iconset_dir/icon_256x256.png" >/dev/null
  sips -z 512 512 "$source_png" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$source_png" --out "$iconset_dir/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$source_png" --out "$iconset_dir/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$iconset_dir" -o "$output_icns"
  rm -rf "$temp_dir"
}

build_app_bundle() {
  swift build --product "$PRODUCT" >&2

  local bin_path app_bundle contents_dir macos_dir resources_dir executable_path resource_bundle_path
  bin_path="$(swift build --show-bin-path)"
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
    create_icns "$ICON_SOURCE" "$resources_dir/$PRODUCT.icns"
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
  <string>$PRODUCT</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_MACOS_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

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
    build_app_bundle
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
