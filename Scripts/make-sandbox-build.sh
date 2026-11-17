#!/bin/bash
# Builds a numbered sandbox app and copies it into the Dropbox builds folder.
#
#   Scripts/make-sandbox-build.sh 26 "Short label" "What changed" "Another change" ...
#
# Checks first: clean working tree, Mac and iOS build, full tests. Then builds Release with the
# fork's identity (Blake's project sets live.cues and Hardened Runtime on, which crashes ad-hoc
# builds on other Macs), copies it to Dropbox, and adds an entry to "Build notes.txt".
# Set SKIP_CHECKS=1 to skip the builds and tests (only when they have just been run).
set -euo pipefail

BUILD="${1:?usage: make-sandbox-build.sh <number> \"<label>\" [\"change\" ...]}"
LABEL="${2:?usage: make-sandbox-build.sh <number> \"<label>\" [\"change\" ...]}"
shift 2

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DROPBOX="${SANDBOX_BUILDS_DIR:-$HOME/Library/CloudStorage/Dropbox/Sandbox/Cues App}"
NUMBER="$(printf '%02d' "$BUILD")"
TARGET="$DROPBOX/cues.live $NUMBER – $LABEL.app"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/sandbox-build.XXXXXX")"
PROJECT=(-project "$ROOT/CuesLive.xcodeproj" -scheme CuesLive)

cd "$ROOT"

[[ -d "$DROPBOX" ]] || { echo "Builds folder not found: $DROPBOX" >&2; exit 1; }
[[ -e "$TARGET" ]] && { echo "Already exists: $TARGET" >&2; exit 1; }
if ls "$DROPBOX" | grep -q "^cues.live $NUMBER – "; then
    echo "Build $NUMBER already exists in $DROPBOX" >&2; exit 1
fi
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    echo "Commit your changes first, so the build matches a commit." >&2; exit 1
fi
COMMIT="$(git rev-parse --short HEAD)"

run() {
    local name="$1"; shift
    echo "▸ $name"
    if ! xcodebuild "$@" > "$WORK/$name.log" 2>&1; then
        grep -E "error:|failed" "$WORK/$name.log" | grep -v ThirdParty | head -20 >&2
        echo "✗ $name failed. Full log: $WORK/$name.log" >&2
        exit 1
    fi
    local warnings
    warnings="$(grep -E "\.swift:[0-9]+:[0-9]+: warning:" "$WORK/$name.log" | grep -v ThirdParty | sort -u || true)"
    if [[ -n "$warnings" ]]; then
        echo "$warnings" >&2
        echo "✗ $name has Swift warnings; the build must stay at zero." >&2
        exit 1
    fi
}

if [[ "${SKIP_CHECKS:-0}" != 1 ]]; then
    run mac-build "${PROJECT[@]}" -destination 'platform=macOS' build
    run ios-build "${PROJECT[@]}" -destination 'generic/platform=iOS Simulator' build
    run tests "${PROJECT[@]}" -destination 'platform=macOS' test
fi

run release "${PROJECT[@]}" -configuration Release -destination 'platform=macOS' \
    -derivedDataPath "$WORK/dd" \
    PRODUCT_BUNDLE_IDENTIFIER=com.spacebear.cues ENABLE_HARDENED_RUNTIME=NO \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= SPARKLE_FEED_URL= \
    CURRENT_PROJECT_VERSION="$BUILD"

APP="$WORK/dd/Build/Products/Release/cues.live.app"
codesign --verify --deep --strict "$APP"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
[[ "$VERSION" == "$BUILD" ]] || { echo "Built version is $VERSION, expected $BUILD" >&2; exit 1; }

echo "▸ copy to Dropbox"
ditto "$APP" "$TARGET"
codesign --verify --deep --strict "$TARGET"

python3 - "$DROPBOX/Build notes.txt" "$NUMBER" "$LABEL" "$(date '+%b %-d, %-I:%M %p')" "$COMMIT" "$@" <<'EOF'
import re, sys
path, number, label, when, commit, *changes = sys.argv[1:]
lines = [f"{number}  {label:<43}{when}  {commit}"]
lines += [f"    - {change}" for change in changes]
entry = "\n".join(lines) + "\n\n"
text = open(path).read()
match = re.search(r"^\d{2}  ", text, re.M)
at = match.start() if match else len(text)
open(path, "w").write(text[:at] + entry + text[at:])
EOF

rm -rf "$WORK"
echo "✓ Build $NUMBER ($COMMIT): $TARGET"
echo "  Log it in SANDBOX_CHANGES.md and push: git push origin sandbox"
