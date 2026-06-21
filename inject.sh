#!/bin/bash
# inject.sh — Build, inject, and package modified Instagram IPA
# Usage: ./inject.sh

set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/Payload/Instagram.app"
BINARY="$APP/Instagram"
TWEAK_DIR="$ROOT/Tweak"
DYLIB_NAME="IGTweak.dylib"
INSERT_DYLIB="/tmp/insert_dylib"
OUTPUT_IPA="$ROOT/Instagram-Modded.ipa"

echo "═══════════════════════════════════════════"
echo "  🔧 Instagram Tweak Builder & Injector"
echo "═══════════════════════════════════════════"
echo ""

# Step 1: Build the tweak dylib
echo "📦 Step 1: Compiling $DYLIB_NAME..."
cd "$TWEAK_DIR"
make clean && make
echo ""

# Step 2: Copy dylib into the app bundle
echo "📁 Step 2: Copying dylib into app bundle..."
mkdir -p "$APP/Frameworks"
cp "$TWEAK_DIR/$DYLIB_NAME" "$APP/Frameworks/$DYLIB_NAME"
echo "   ✅ Copied to Frameworks/$DYLIB_NAME"
echo ""

# Step 3: Inject load command into Instagram binary
echo "💉 Step 3: Injecting load command into binary..."
if otool -L "$BINARY" | grep -q "$DYLIB_NAME"; then
    echo "   ⚠️  Load command already exists, skipping injection"
else
    "$INSERT_DYLIB" --strip-codesig --inplace \
        "@rpath/$DYLIB_NAME" "$BINARY"
    echo "   ✅ Load command injected"
fi
echo ""

# Step 4: Remove PlugIns to avoid signing issues
echo "🗑  Step 4: Removing PlugIns (avoids signing issues)..."
if [ -d "$APP/PlugIns" ]; then
    rm -rf "$APP/PlugIns"
    echo "   ✅ PlugIns removed"
else
    echo "   ⚠️  PlugIns already removed"
fi
echo ""

# Step 5: Remove Watch app if present
if [ -d "$APP/Watch" ]; then
    echo "🗑  Step 5: Removing Watch app..."
    rm -rf "$APP/Watch"
    echo "   ✅ Watch app removed"
fi

# Step 6: Strip existing code signatures
echo "🔓 Step 6: Stripping code signatures..."
find "$APP" -name "_CodeSignature" -type d -exec rm -rf {} + 2>/dev/null || true
echo "   ✅ Code signatures stripped"
echo ""

# Step 7: Package as IPA
echo "📱 Step 7: Packaging modded IPA..."
cd "$ROOT"
rm -f "$OUTPUT_IPA"
zip -r -q "$OUTPUT_IPA" Payload/
echo "   ✅ Created: $OUTPUT_IPA"
echo ""

# Step 8: Verify
echo "═══════════════════════════════════════════"
echo "  ✅ Verification"
echo "═══════════════════════════════════════════"
echo ""
echo "Binary load commands:"
otool -L "$BINARY" | grep -E "(IGTweak|rpath)" || echo "   (check manually)"
echo ""
echo "Dylib info:"
file "$APP/Frameworks/$DYLIB_NAME"
echo ""
IPA_SIZE=$(du -sh "$OUTPUT_IPA" | cut -f1)
echo "📱 Modded IPA: $OUTPUT_IPA ($IPA_SIZE)"
echo ""
echo "═══════════════════════════════════════════"
echo "  🎉 Done! Install with AltStore/Sideloadly/TrollStore"
echo "═══════════════════════════════════════════"
