#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
APP="温度计.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun clang -O2 -fobjc-arc -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=13.0 -framework Cocoa -framework IOKit Source/main.m -o "$APP/Contents/MacOS/MacTemperature"
cp Source/Info.plist "$APP/Contents/Info.plist"
cp THIRD-PARTY-LICENSE.txt "$APP/Contents/Resources/THIRD-PARTY-LICENSE.txt"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
