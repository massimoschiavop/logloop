#!/bin/zsh
#
# Crea un IPA non firmato di LogLoop (KravaSign e simili lo rifirmano col proprio certificato).
#
# Uso:
#   ./scripts/build_ipa.sh [versione] [build]   # es. ./scripts/build_ipa.sh 1.2 7
#
# L'IPA viene scritto in build/LogLoop.ipa.

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-1.0}"
BUILD_NUMBER="${2:-1}"
OUT_DIR="build"
DERIVED_DATA="$OUT_DIR/DerivedData"

rm -rf "$OUT_DIR/Payload" "$OUT_DIR/LogLoop.ipa"
mkdir -p "$OUT_DIR"

xcodebuild \
  -project LogLoop.xcodeproj \
  -scheme LogLoop \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  -quiet \
  build

mkdir -p "$OUT_DIR/Payload"
cp -R "$DERIVED_DATA/Build/Products/Release-iphoneos/LogLoop.app" "$OUT_DIR/Payload/"
(cd "$OUT_DIR" && zip -qry LogLoop.ipa Payload)
rm -rf "$OUT_DIR/Payload"

echo "Creato $OUT_DIR/LogLoop.ipa (versione $VERSION, build $BUILD_NUMBER)"
