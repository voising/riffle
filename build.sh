#!/bin/zsh
# Builds AltTab and assembles a runnable .app bundle in build/.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/AltTab.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/AltTab "$APP/Contents/MacOS/AltTab"
cp Info.plist "$APP/Contents/Info.plist"
cp branding/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Sign with a real identity when available: TCC ties the Accessibility grant
# to the code signature, and ad-hoc signatures change on every rebuild —
# which silently invalidates the grant. A certificate keeps it stable.
# Prefer the team used across our projects (see plume: VLZY44ZX2X),
# fall back to any Apple Development identity.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/VLZY44ZX2X/{print $2; exit}')
if [[ -z "${IDENTITY:-}" ]]; then
  IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/{print $2; exit}')
fi
if [[ -n "${IDENTITY:-}" ]]; then
  echo "Signing with: $IDENTITY"
  codesign --force --sign "$IDENTITY" "$APP"
else
  echo "No Apple Development identity found; ad-hoc signing (permissions reset on each rebuild)"
  codesign --force --sign - "$APP"
fi

echo "Built $APP"
echo "Run:  open $APP"
