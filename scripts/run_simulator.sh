#!/bin/zsh
#
# Avvia l'app Simulator di Xcode e prepara (boot) un simulatore iOS.
#
# Uso:
#   ./scripts/run_simulator.sh                  # usa il device di default
#   ./scripts/run_simulator.sh "iPhone 16 Pro"  # usa un device specifico
#
# Il nome del device deve corrispondere a uno di quelli elencati da:
#   xcrun simctl list devices available

set -euo pipefail

DEFAULT_DEVICE="iPhone 16 Pro"
DEVICE_NAME="${1:-$DEFAULT_DEVICE}"

echo "Cerco il simulatore \"$DEVICE_NAME\"..."

DEVICE_UDID=$(xcrun simctl list devices available | \
  awk -v name="$DEVICE_NAME" -F '[()]' '
    $0 ~ name" \\(" { print $2; exit }
  ')

if [[ -z "$DEVICE_UDID" ]]; then
  echo "Simulatore \"$DEVICE_NAME\" non trovato tra i device disponibili." >&2
  echo "Device disponibili:" >&2
  xcrun simctl list devices available >&2
  exit 1
fi

echo "Trovato device UDID: $DEVICE_UDID"

# Avvia l'app Simulator (se non è già aperta)
open -a Simulator

# Fa il boot del device, ignorando l'errore se è già avviato
BOOT_STATE=$(xcrun simctl list devices | grep "$DEVICE_UDID" | grep -o "Booted" || true)
if [[ "$BOOT_STATE" != "Booted" ]]; then
  echo "Avvio (boot) del simulatore..."
  xcrun simctl boot "$DEVICE_UDID"
else
  echo "Il simulatore è già avviato."
fi

# Porta la finestra del Simulator in primo piano
open -a Simulator

echo "Simulatore pronto: $DEVICE_NAME ($DEVICE_UDID)"
