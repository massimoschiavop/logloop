#!/bin/zsh
#
# Compila LogLoop e la installa/avvia sul simulatore iOS attualmente avviato,
# oppure sul telefono collegato se passi -p.
#
# Uso:
#   ./scripts/build_and_run.sh        # simulatore (richiede un simulatore già avviato)
#   ./scripts/build_and_run.sh -p     # telefono collegato via USB/rete
#
# Se nessun simulatore è avviato, avvialo prima con:
#   ./scripts/run_simulator.sh

set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="com.massimoschiavo.logloop"

ON_PHONE=0
while getopts "p" opt; do
  case "$opt" in
    p) ON_PHONE=1 ;;
    *) echo "Uso: $0 [-p]" >&2; exit 1 ;;
  esac
done

if [[ "$ON_PHONE" -eq 1 ]]; then
  DEVICE_UDID=$(xcrun xctrace list devices 2>&1 \
    | sed -n '/== Devices ==/,/== Simulators ==/p' \
    | grep -i "iphone" \
    | grep -oE '\([A-F0-9-]+\)$' \
    | tr -d '()' \
    | head -1)

  if [[ -z "$DEVICE_UDID" ]]; then
    echo "Nessun iPhone collegato." >&2
    exit 1
  fi

  echo "Compilo LogLoop per il telefono ($DEVICE_UDID)..."
  xcodebuild -project LogLoop.xcodeproj -scheme LogLoop -configuration Debug \
    -destination "id=$DEVICE_UDID" -allowProvisioningUpdates \
    -derivedDataPath build/DerivedData build

  APP_PATH="build/DerivedData/Build/Products/Debug-iphoneos/LogLoop.app"

  echo "Installo l'app sul telefono..."
  xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH"

  echo "Avvio l'app..."
  xcrun devicectl device process launch --device "$DEVICE_UDID" "$BUNDLE_ID"

  echo "Fatto."
  exit 0
fi

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
