#!/bin/bash

# Debug script to compare local vs GitHub secrets
echo "🔍 Debugging Secret Differences"
echo "================================"

# Check local API key file
LOCAL_KEY="/Users/rob/Downloads/AuthKey_923FC92FTY.p8"
if [ -f "$LOCAL_KEY" ]; then
    echo "✅ Local API key file found"
    echo "Local file size: $(wc -c < "$LOCAL_KEY") bytes"
    echo "Local file hash: $(shasum -a 256 "$LOCAL_KEY" | cut -d' ' -f1)"
    echo "Local first line: $(head -1 "$LOCAL_KEY")"
    echo "Local last line: $(tail -1 "$LOCAL_KEY")"
    echo ""
else
    echo "❌ Local API key file not found"
fi

# Ask user to check their GitHub secrets
echo "🔍 Please check your GitHub secrets:"
echo "=================================="
echo ""
echo "1. Go to your GitHub repository"
echo "2. Settings → Secrets and variables → Actions"
echo "3. Check these secrets:"
echo ""
echo "APP_STORE_CONNECT_API_KEY_ID:"
echo "  Expected: 923FC92FTY"
echo "  Length: 10 characters"
echo ""
echo "APP_STORE_CONNECT_ISSUER_ID:"
echo "  Expected: c12f2bdf-c493-41c0-ba74-8465a55f195b"
echo "  Length: 36 characters"
echo ""
echo "APP_STORE_CONNECT_PRIVATE_KEY:"
echo "  Expected content (copy exactly):"
echo "-----BEGIN PRIVATE KEY-----"
cat "$LOCAL_KEY" | tail -n +2 | head -n -1
echo "-----END PRIVATE KEY-----"
echo ""
echo "  Expected length: $(wc -c < "$LOCAL_KEY") characters"
echo "  Expected hash: $(shasum -a 256 "$LOCAL_KEY" | cut -d' ' -f1)"
echo ""

echo "🧪 Common Issues:"
echo "=================="
echo "• Extra spaces or newlines at start/end of private key"
echo "• Missing -----BEGIN PRIVATE KEY----- header"
echo "• Missing -----END PRIVATE KEY----- footer"
echo "• Wrong API Key ID (typos in 923FC92FTY)"
echo "• Wrong Issuer ID (typos in UUID)"
echo "• Copy/paste errors introducing invisible characters"
echo ""

echo "💡 Recommendation:"
echo "=================="
echo "1. Delete all three GitHub secrets"
echo "2. Recreate them one by one, being very careful with copy/paste"
echo "3. For the private key, copy from this script output above"
echo "4. Test the workflow again"