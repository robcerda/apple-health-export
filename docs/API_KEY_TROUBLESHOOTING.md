# App Store Connect API Key Troubleshooting Guide

## 🚨 Current Issue: "Failed to load AuthKey file"

Your deployment is failing with authentication errors despite having all required secrets configured. This typically indicates the API key content itself is corrupted or incorrectly formatted.

---

## 🔍 Step 1: Verify Your Current API Key

### **Check API Key Format**
Your `APP_STORE_CONNECT_PRIVATE_KEY` secret should look exactly like this:

```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgPaXyFvZfNVr...
[multiple lines of base64 encoded content]
...additional lines...
-----END PRIVATE KEY-----
```

### **Common Formatting Issues:**
- ❌ Missing header/footer lines
- ❌ Extra spaces or newlines at beginning/end
- ❌ Corrupted base64 content
- ❌ Wrong file type (should be .p8, not .p12)

---

## 🛠️ Step 2: Create a Fresh API Key

Since your current key may be corrupted, let's create a new one:

### **A. Revoke Current API Key (Optional but Recommended)**
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **Users and Access** → **Integrations** → **API Keys**
3. Find your current key and click **Revoke**
4. Confirm revocation

### **B. Create New API Key**
1. Click **Generate API Key** or **+**
2. Enter name: `GitHub Actions Deploy v2`
3. Select **App Manager** role (required for uploads)
4. Click **Generate**

### **C. Download Immediately**
⚠️ **CRITICAL**: You can only download the .p8 file once!

1. **Download the .p8 file** immediately after creation
2. **Copy the Key ID** (shown in the list - format: `2X9R4HXF34`)
3. **Copy the Issuer ID** (shown at top of page - format: UUID)

---

## 📝 Step 3: Update GitHub Secrets

### **A. Extract API Key Content**
1. Open the downloaded .p8 file in TextEdit or VS Code
2. Copy the **entire contents** including the header and footer lines
3. Ensure no extra spaces or characters

### **B. Update GitHub Secrets**
Go to your repository → Settings → Secrets and variables → Actions

Update these three secrets:

#### **1. APP_STORE_CONNECT_API_KEY_ID**
- Delete the old secret
- Create new with the Key ID from the new API key
- Format: `2X9R4HXF34` (example)

#### **2. APP_STORE_CONNECT_ISSUER_ID** 
- Verify this matches the Issuer ID shown in App Store Connect
- Format: `57246542-96fe-1a63-e053-0824d011072a` (example UUID)

#### **3. APP_STORE_CONNECT_PRIVATE_KEY**
- Delete the old secret
- Create new with the complete .p8 file contents
- Include header and footer lines
- No extra spaces at beginning/end

---

## 🧪 Step 4: Test the New Configuration

### **Manual Test**
Run the App Store deployment workflow manually:
1. Go to **Actions** tab in your repository
2. Click **Deploy to App Store** workflow
3. Click **Run workflow** → **Run workflow**
4. Monitor the logs for the upload step

### **Expected Success Output**
```
✅ API key files created at:
-rw------- 1 runner staff 227 Dec 27 10:30 ~/.private_keys/AuthKey_[KEY_ID].p8

🚀 Testing App Store Connect upload...
📱 Uploading: /tmp/export/HealthExporter.ipa

*** Uploading...
*** Upload Successful.
```

---

## 🔧 Step 5: Additional Verification

### **A. Verify API Key Permissions**
In App Store Connect:
1. Go to **Users and Access** → **Integrations** → **API Keys**
2. Find your new API key
3. Ensure it shows **App Manager** role
4. Check that it's **Active** (not revoked)

### **B. Verify App Store Connect App**
1. Go to **My Apps** in App Store Connect
2. Find your Health Exporter app
3. Ensure the bundle ID matches: `com.amnesic.dev.healthexporter`
4. Check that the app is ready to receive builds

---

## 🚩 Common Issues and Solutions

### **Issue: "Authentication failed"**
**Solution**: 
- Verify Issuer ID is correct (UUID format)
- Ensure API key has App Manager role
- Check that API key is not revoked

### **Issue: "Invalid private key format"**
**Solution**:
- Ensure you're using the .p8 file (not .p12)
- Verify header/footer lines are intact
- Check for hidden characters or encoding issues

### **Issue: "Bundle identifier not found"**
**Solution**:
- Verify bundle ID in Xcode matches App Store Connect
- Ensure provisioning profile includes correct bundle ID
- Check that app exists in App Store Connect

---

## 🎯 Step 6: Security Best Practices

### **After Successful Upload:**
1. **Store backup** of the .p8 file securely (password manager)
2. **Document the Key ID** for future reference
3. **Set calendar reminder** to renew before expiration (1 year)

### **Secret Management:**
- Never commit API keys to source code
- Use GitHub's secret scanner alerts
- Regularly rotate API keys (annually)

---

## 📞 Need Help?

If you're still encountering issues after following this guide:

1. **Check GitHub Actions logs** for specific error messages
2. **Verify all secrets** are correctly formatted
3. **Test with a simple API call** to App Store Connect first
4. **Consider creating a minimal test app** to isolate the issue

---

## 📋 Checklist for Success

- [ ] Created new API key in App Store Connect
- [ ] Downloaded .p8 file immediately 
- [ ] Copied Key ID and Issuer ID
- [ ] Updated all three GitHub secrets
- [ ] Verified API key has App Manager role
- [ ] Tested deployment workflow manually
- [ ] Confirmed successful upload message

**Once this checklist is complete, your App Store uploads should work reliably.**