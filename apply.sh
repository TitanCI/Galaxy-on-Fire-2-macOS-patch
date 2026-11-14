#!/bin/zsh
# Usage: patch/apply.sh [path/to/original.app] [output.app]
# Default: reads /Applications/Galaxy on Fire 2 Full HD.app (left unchanged) and writes
# the patched copy to "Galaxy on Fire 2 Full HD.app" next to this script, replacing any older copy.

# Abort on any error, on unset variables, and on failures inside pipes.
set -euo pipefail

# Folder containing this script (resolves symlinks and relative paths).
HERE="${0:A:h}"
# Original app (argument 1, default: the installed app in /Applications).
SRC="${1:-/Applications/Galaxy on Fire 2 Full HD.app}"
# Where the patched copy is written (argument 2).
DST="${2:-$HERE/Galaxy on Fire 2 Full HD.app}"
# Name of the game's executable inside Contents/MacOS.
EXE="Galaxy on Fire 2 Full HD"
# File name of the shim library.
DYLIB="libgof2fix.dylib"

# Stop with a message if the original app does not exist.
[[ -d "$SRC" ]] || { echo "Source app not found: $SRC" >&2; exit 1; }
# Stop with a hint if the compiler is missing.
command -v clang >/dev/null || { echo "Install Xcode command line tools: xcode-select --install" >&2; exit 1; }

# Remove any earlier patched copy.
rm -rf "$DST"
# Copy the app; "-c" makes a fast APFS clone, with a normal copy as fallback.
cp -Rc "$SRC" "$DST" 2>/dev/null || cp -R "$SRC" "$DST"

# A stray file in the bundle root breaks the bundle seal.
rm -f "$DST/embedded.mobileprovision"

# Path to the copied executable.
B="$DST/Contents/MacOS/$EXE"
# Temporary file for the thinned executable.
TMP="$(mktemp)"
# Keep only the 64-bit Intel part of the executable (drops the unused 32-bit part).
lipo "$B" -thin x86_64 -output "$TMP"
# Put the thinned executable in place and delete the temporary file.
cp "$TMP" "$B" && rm -f "$TMP"
# Remove the Apple signature, which the next steps would invalidate anyway.
codesign --remove-signature "$B"

# Compile the shim into a dynamic library inside the app's Frameworks folder.
clang -dynamiclib -arch x86_64 -fobjc-arc -mmacosx-version-min=11.0 \
  -framework Cocoa -framework Security "$HERE/src/gof2fix.m" \
  -install_name "@loader_path/../Frameworks/$DYLIB" \
  -o "$DST/Contents/Frameworks/$DYLIB"

# Add a load command so the game loads the shim at startup.
python3 "$HERE/tools/inject.py" "$B" "@loader_path/../Frameworks/$DYLIB"

# Extended attributes on copied files make codesign fail with "detritus not allowed".
xattr -cr "$DST"
# Re-sign every bundled library ad hoc ("-" means no certificate).
for f in "$DST"/Contents/Frameworks/*; do codesign -f -s - "$f"; done
# Re-sign the whole app ad hoc, keeping only the sandbox, network and USB entitlements.
codesign -f -s - --entitlements "$HERE/config/ent.plist" "$DST"
# Strip quarantine and other extended attributes that could trigger Gatekeeper prompts.
xattr -cr "$DST"
# Check that the new signature is valid.
codesign -v "$DST"

# Report where the patched app is.
echo "Patched app: $DST"
