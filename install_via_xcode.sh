#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
CERT="Apple Development: mukarramovsh@gmail.com (Y2D56DK4HW)"
ENTITLEMENTS="$ROOT/entitlements.plist"

echo "📦 Extracting IPA..."
rm -rf Payload_tmp
unzip -q Instagram-Modded.ipa -d Payload_tmp

echo "✍️ Codesigning with your Apple Development certificate..."
echo "   Certificate: $CERT"
echo "   Entitlements: $ENTITLEMENTS"

# Sign all frameworks and dylibs first
find Payload_tmp/Payload/Instagram.app -type d -name "*.framework" -exec \
    codesign --force --sign "$CERT" --entitlements "$ENTITLEMENTS" {} \;
find Payload_tmp/Payload/Instagram.app -type f -name "*.dylib" -exec \
    codesign --force --sign "$CERT" {} \;

# Sign the main app bundle WITH entitlements (critical for Keychain access)
codesign --force --sign "$CERT" --entitlements "$ENTITLEMENTS" \
    Payload_tmp/Payload/Instagram.app

echo "✅ App signed with entitlements!"
echo ""
echo "🔑 Verifying entitlements..."
codesign -d --entitlements :- Payload_tmp/Payload/Instagram.app 2>/dev/null | head -20
echo ""
echo "📱 Installing via ios-deploy..."
ios-deploy --bundle Payload_tmp/Payload/Instagram.app

echo ""
echo "🎉 Done! App installed on device."
