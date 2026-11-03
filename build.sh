#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="DockStayPutter"
BUNDLE_ID="com.ryanlowe.DockStayPutter"
APP="build/${APP_NAME}.app"

INSTALL=0
for arg in "$@"; do
    case "$arg" in
        --install) INSTALL=1 ;;
        *) echo "Unknown option: $arg" >&2; echo "Usage: ./build.sh [--install]" >&2; exit 1 ;;
    esac
done

swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/$APP_NAME" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Icon/AppIcon.icns "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"

if [[ "$INSTALL" -eq 1 ]]; then
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "$APP" /Applications/
    echo "Installed to /Applications/${APP_NAME}.app"
    open "/Applications/${APP_NAME}.app"
else
    echo "Built $(pwd)/$APP"
fi

echo
echo "Next steps:"
echo "  1. Open System Settings > Privacy & Security > Accessibility."
echo "  2. Turn on Dock Stay Putter (add it with the + button if it's missing)."
echo "  3. The app starts fencing the cursor as soon as access is granted."
