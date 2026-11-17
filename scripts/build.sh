#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
python3 scripts/update-settings-search.py --check
CONFIGURATION="${1:-release}"
if [[ "$CONFIGURATION" != "release" && "$CONFIGURATION" != "debug" ]]; then
  echo "Usage: scripts/build.sh [release|debug]" >&2
  exit 2
fi
# Leave the existing host-only build unchanged unless explicitly requested.
# A universal app must include matching slices in its dynamic libraries too.
BUILD_ARGS=(--configuration "$CONFIGURATION")
if [[ -n "${LYRICSX_SDK:-}" ]]; then
  export SDKROOT="$LYRICSX_SDK"
  BUILD_ARGS+=(--sdk "$LYRICSX_SDK")
fi
if [[ -n "${LYRICSX_BUILD_PATH:-}" ]]; then
  BUILD_ARGS+=(--scratch-path "$LYRICSX_BUILD_PATH")
fi
REQUESTED_ARCHS=""
case "${LYRICSX_ARCHS:-}" in
  '') ;;
  arm64|x86_64) REQUESTED_ARCHS="$LYRICSX_ARCHS" ;;
  universal|arm64,x86_64|x86_64,arm64) REQUESTED_ARCHS="arm64 x86_64" ;;
  *)
    echo 'LYRICSX_ARCHS must be arm64, x86_64, or universal (arm64,x86_64).' >&2
    exit 2
    ;;
esac
for architecture in $REQUESTED_ARCHS; do
  BUILD_ARGS+=(--arch "$architecture")
done
swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
mkdir -p "$PROJECT_ROOT/build"
STAGE_ROOT="$(mktemp -d "$PROJECT_ROOT/build/.lyricsx-stage.XXXXXX")"
trap 'rm -rf "$STAGE_ROOT"' EXIT
APP="$STAGE_ROOT/LyricsX TB.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/LyricsX" "$APP/Contents/MacOS/LyricsX"
mkdir -p "$APP/Contents/Library/LaunchAgents"
cp Resources/com.lyricsx.modern.netease-launch.plist "$APP/Contents/Library/LaunchAgents/"
AGENT_ARCH_ARGS=()
for architecture in $REQUESTED_ARCHS; do AGENT_ARCH_ARGS+=(-arch "$architecture"); done
# swiftc accepts one target; build slices separately for a universal package.
AGENT_ARCHS="${REQUESTED_ARCHS:-$(uname -m)}"
AGENT_SLICES=()
for architecture in $AGENT_ARCHS; do
  slice="$STAGE_ROOT/NetEaseLaunchAgent-$architecture"
  xcrun swiftc -O -swift-version 5 -target "$architecture-apple-macos26.0" Resources/NetEaseLaunchAgent.swift -o "$slice"
  AGENT_SLICES+=("$slice")
done
lipo -create "${AGENT_SLICES[@]}" -output "$APP/Contents/MacOS/LyricsXNetEaseLaunchAgent"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/run.pl Resources/netease-reader.pl Resources/MediaRemoteAdapter-LICENSE Resources/THIRD-PARTY-NOTICES.txt LICENSE "$APP/Contents/Resources/"
# The dedicated read-only NetEase client reader is loaded by the platform Perl host.
READER_ARCH_ARGS=()
for architecture in $REQUESTED_ARCHS; do READER_ARCH_ARGS+=(-arch "$architecture"); done
clang -dynamiclib -install_name @rpath/libLyricsXNeteaseReader.dylib -fobjc-arc -fblocks -framework Foundation -mmacosx-version-min=26.0 "${READER_ARCH_ARGS[@]}" \
  Resources/NeteaseReader.m -o "$APP/Contents/Frameworks/libLyricsXNeteaseReader.dylib"
iconutil -c icns Resources/Icon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
for dylib in "$BIN_DIR"/*.dylib; do
  [[ -e "$dylib" ]] || continue
  cp "$dylib" "$APP/Contents/Frameworks/"
done
for bundle in "$BIN_DIR"/*.bundle; do
  [[ -d "$bundle" ]] || continue
  ditto "$bundle" "$APP/Contents/Resources/$(basename "$bundle")"
done
if [[ -n "$REQUESTED_ARCHS" ]]; then
  for binary in "$APP/Contents/MacOS/LyricsX" "$APP/Contents/Frameworks/"*.dylib; do
    [[ -e "$binary" ]] || continue
    for architecture in $REQUESTED_ARCHS; do
      /usr/bin/lipo -verify_arch "$architecture" "$binary"
    done
  done
fi
# SPM uses @rpath; packaged applications must resolve dependencies beside the executable.
if ! otool -l "$APP/Contents/MacOS/LyricsX" | /usr/bin/grep -q '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath '@executable_path/../Frameworks' "$APP/Contents/MacOS/LyricsX"
fi
# Public packages must not carry local source paths from SwiftPM debug info.
for binary in "$APP/Contents/MacOS/"* "$APP/Contents/Frameworks/"*.dylib; do
  [[ -f "$binary" ]] || continue
  strip -S "$binary"
done
bash "$PROJECT_ROOT/scripts/check-runtime-compatibility.sh" "$APP"
SIGN_IDENTITY="${LYRICSX_SIGN_IDENTITY:--}"
for dylib in "$APP/Contents/Frameworks"/*.dylib; do
  codesign --force --sign "$SIGN_IDENTITY" "$dylib"
done
codesign --force --sign "$SIGN_IDENTITY" "$APP/Contents/MacOS/LyricsXNetEaseLaunchAgent"
codesign --force --sign "$SIGN_IDENTITY" --entitlements Resources/LyricsX.entitlements "$APP"
codesign --verify --deep --strict "$APP"
TARGET_APP="$PROJECT_ROOT/build/LyricsX TB.app"
rm -rf "$TARGET_APP"
mv "$APP" "$TARGET_APP"
echo "Built: $TARGET_APP"
