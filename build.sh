#!/usr/bin/env bash
# Build a Windows release: build/LimitBreak.zip (exe with the game icon + .pck + icon + readme).
# Usage: bash build.sh            then: gh release create vX.Y.Z build/LimitBreak.zip
# Needs tools/rcedit-x64.exe (https://github.com/electron/rcedit/releases) for the exe icon.
set -e
cd "$(dirname "$0")"
W="${GODOT_DIR:-/c/Users/jihye/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe}"
G="$W/Godot_v4.7.2-stable_win64_console.exe"
mkdir -p build
timeout 180 "$G" --headless --path . --import < /dev/null > /dev/null 2>&1 || true
timeout 180 "$G" --headless --path . --export-pack "Windows Desktop" build/LimitBreak.pck < /dev/null > /dev/null 2>&1
cp "$W/Godot_v4.7.2-stable_win64.exe" build/LimitBreak.exe
cp assets/icon/icon.ico build/icon.ico
if [ -x tools/rcedit-x64.exe ]; then
  tools/rcedit-x64.exe build/LimitBreak.exe --set-icon build/icon.ico \
    --set-version-string ProductName "LIMIT BREAK" --set-version-string FileDescription "LIMIT BREAK"
fi
rm -f build/LimitBreak.zip
powershell -NoProfile -Command "Set-Location build; Compress-Archive -Path LimitBreak.exe, LimitBreak.pck, icon.ico, '읽어주세요.txt' -DestinationPath LimitBreak.zip -CompressionLevel Optimal"
ls -la build/LimitBreak.zip
