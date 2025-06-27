#!/bin/bash

# Test App Store Connect API credentials locally
# This helps verify your credentials before running the GitHub workflow

echo "🔍 Testing App Store Connect API Credentials"
echo "============================================="

# Check if API key file exists
API_KEY_FILE="/Users/rob/Downloads/AuthKey_923FC92FTY.p8"
if [ ! -f "$API_KEY_FILE" ]; then
    echo "❌ API key file not found at: $API_KEY_FILE"
    exit 1
fi

echo "✅ API key file found: $API_KEY_FILE"

# Display file info
echo "📄 API key file info:"
echo "Size: $(wc -c < "$API_KEY_FILE") bytes"
echo "First line: $(head -1 "$API_KEY_FILE")"
echo "Last line: $(tail -1 "$API_KEY_FILE")"
echo ""

# Test with altool
echo "🚀 Testing credentials with altool..."
echo "Note: You'll need to provide your Issuer ID"
echo ""

# Prompt for Issuer ID
read -p "Enter your App Store Connect Issuer ID (from App Store Connect): " ISSUER_ID

if [ -z "$ISSUER_ID" ]; then
    echo "❌ Issuer ID is required"
    exit 1
fi

echo "Testing with:"
echo "- API Key ID: 923FC92FTY"
echo "- Issuer ID: $ISSUER_ID"
echo "- API Key File: $API_KEY_FILE"
echo ""

# Copy API key to expected location
mkdir -p ~/.private_keys
cp "$API_KEY_FILE" ~/.private_keys/
chmod 600 ~/.private_keys/AuthKey_923FC92FTY.p8

# Test with altool
echo "🧪 Running altool test..."
/Applications/Xcode.app/Contents/SharedFrameworks/ContentDeliveryServices.framework/Frameworks/AppStoreService.framework/Support/altool \
    --list-apps \
    --apiKey 923FC92FTY \
    --apiIssuer "$ISSUER_ID" \
    --verbose

RESULT=$?

if [ $RESULT -eq 0 ]; then
    echo ""
    echo "✅ SUCCESS! Your credentials are working correctly."
    echo "Your GitHub secret APP_STORE_CONNECT_ISSUER_ID should be: $ISSUER_ID"
else
    echo ""
    echo "❌ FAILED! Check your Issuer ID and API key permissions."
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Verify the Issuer ID is correct in App Store Connect"
    echo "2. Ensure your API key has 'App Manager' role"
    echo "3. Check that your API key is not revoked"
fi

# Clean up
rm -f ~/.private_keys/AuthKey_923FC92FTY.p8