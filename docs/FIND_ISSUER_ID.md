# Find Your App Store Connect Issuer ID

## 🎯 Current Issue
Your deployment is now successfully creating the API key file, but failing with "401 Unauthorized - Failure to authenticate." This typically means your `APP_STORE_CONNECT_ISSUER_ID` secret is incorrect.

---

## 🔍 How to Find Your Issuer ID

### **Step 1: Go to App Store Connect**
1. Open [App Store Connect](https://appstoreconnect.apple.com)
2. Log in with your Apple ID

### **Step 2: Navigate to API Keys**
1. Click **Users and Access** (in the top navigation)
2. Click **Integrations** tab
3. Click **API Keys**

### **Step 3: Find the Issuer ID**
At the top of the API Keys page, you'll see:
```
Issuer ID: [UUID-FORMAT-STRING]
```

**Example format**: `57246542-96fe-1a63-e053-0824d011072a`

---

## 🛠️ Update Your GitHub Secret

### **Current API Key Info:**
- **API Key ID**: `923FC92FTY` (from your .p8 file)
- **API Key File**: ✅ Correctly formatted
- **Issuer ID**: ❌ Needs to be updated

### **Steps to Fix:**
1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Find `APP_STORE_CONNECT_ISSUER_ID` secret
4. Click **Update**
5. Paste the Issuer ID from App Store Connect (UUID format)
6. Click **Update secret**

---

## 🔧 Alternative: Use App Store Connect CLI

If you have access to a Mac with Xcode installed, you can also verify your credentials:

```bash
# Test your API key credentials
/Applications/Xcode.app/Contents/SharedFrameworks/ContentDeliveryServices.framework/Frameworks/AppStoreService.framework/Support/altool \
  --list-apps \
  --apiKey 923FC92FTY \
  --apiIssuer [YOUR_ISSUER_ID]
```

This should return a list of your apps if the credentials are correct.

---

## 📋 Verification Checklist

- [ ] Found Issuer ID in App Store Connect
- [ ] Issuer ID is in UUID format (8-4-4-4-12 characters)
- [ ] Updated GitHub secret `APP_STORE_CONNECT_ISSUER_ID`
- [ ] API key shows as "Active" in App Store Connect
- [ ] API key has "App Manager" role

---

## 🎯 Expected Result

After updating the Issuer ID, your next deployment should show:
```
✅ Successfully uploaded to App Store Connect
```

Instead of the 401 authentication error.

---

## 💡 Pro Tip

The Issuer ID is the same for all API keys in your Apple Developer account. If you have other API keys, they all use the same Issuer ID.