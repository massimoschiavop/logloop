#!/bin/zsh
#
# Compila LogLoop e la installa/avvia sul simulatore iOS attualmente avviato.
#
# Uso:
#   ./scripts/build_and_run.sh
#
# Se nessun simulatore è avviato, avvialo prima con:
#   ./scripts/run_simulator.sh

set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="com.massimoschiavo.logloop"

DEVICE_UDID=$(xcrun simctl list devices | grep "(Booted)" | head -1 | grep -o '[0-9A-F]\{8\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{4\}-[0-9A-F]\{12\}')

if [[ -z "$DEVICE_UDID" ]]; then
  echo "Nessun simulatore avviato. Avvialo con ./scripts/run_simulator.sh" >&2
  exit 1
fi

echo "Compilo LogLoop per il simulatore $DEVICE_UDID..."
xcodebuild -project LogLoop.xcodeproj -scheme LogLoop -configuration Debug \
  -destination "id=$DEVICE_UDID" -derivedDataPath build/DerivedData build

APP_PATH="build/DerivedData/Build/Products/Debug-iphonesimulator/LogLoop.app"

echo "Installo l'app..."
xcrun simctl install "$DEVICE_UDID" "$APP_PATH"

echo "Avvio l'app..."
open -a "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app" 2>/dev/null || true
xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID"

echo "Fatto."
