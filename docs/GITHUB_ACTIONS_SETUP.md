# GitHub Actions Setup for App Store Deployment

This guide explains how to configure GitHub Actions secrets for automated App Store deployment.

## 🔐 Required GitHub Secrets

You need to configure these secrets in your GitHub repository:

### **App Store Connect API Key Secrets**

#### **1. APP_STORE_CONNECT_API_KEY_ID**
- **What**: Your App Store Connect API Key ID
- **Where to find**: App Store Connect → Users and Access → Integrations → API Keys
- **Format**: `2X9R4HXF34` (example)

#### **2. APP_STORE_CONNECT_ISSUER_ID**  
- **What**: Your App Store Connect Issuer ID
- **Where to find**: App Store Connect → Users and Access → Integrations → API Keys (at the top)
- **Format**: `57246542-96fe-1a63-e053-0824d011072a` (example UUID)

#### **3. APP_STORE_CONNECT_PRIVATE_KEY**
- **What**: Contents of your App Store Connect API private key (.p8 file)
- **Where to find**: Download the .p8 file when creating the API key
- **Format**: The entire contents of the .p8 file including headers
- **Example**:
```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgPaXyFvZfNVr...
[... more lines ...]
-----END PRIVATE KEY-----
```

### **Code Signing Secrets**

#### **4. DISTRIBUTION_CERTIFICATE_BASE64**
- **What**: Your Apple Distribution certificate (.p12 file) encoded as base64
- **How to create**: 
  ```bash
  base64 -i YourDistributionCertificate.p12 -o encoded_cert.txt
  ```
- **Copy the entire contents** of encoded_cert.txt

#### **5. DISTRIBUTION_P12_PASSWORD**
- **What**: Password for your Distribution certificate .p12 file
- **Format**: Plain text password

#### **6. DISTRIBUTION_PROVISION_PROFILE_BASE64**
- **What**: Your App Store provisioning profile (.mobileprovision) encoded as base64
- **How to create**:
  ```bash
  base64 -i YourAppStoreProfile.mobileprovision -o encoded_profile.txt
  ```
- **Copy the entire contents** of encoded_profile.txt

#### **7. TEAM_ID**
- **What**: Your Apple Developer Team ID
- **Where to find**: Apple Developer Account → Membership → Team ID
- **Format**: `8C482LBWXU` (example)

#### **8. KEYCHAIN_PASSWORD**
- **What**: Password for temporary keychain (can be any secure password)
- **Format**: Choose a strong password like `TempKeychain2024!`

### **Optional Build Secrets**

#### **9. BUILD_CERTIFICATE_BASE64** (Optional)
- **What**: Your Apple Development certificate for debug builds
- **Same process as distribution certificate**

#### **10. BUILD_PROVISION_PROFILE_BASE64** (Optional)
- **What**: Development provisioning profile for debug builds
- **Same process as distribution profile**

#### **11. P12_PASSWORD** (Optional)
- **What**: Password for development certificate
- **Only needed if using development certificates**

## 🛠️ How to Set Up Secrets

### **Step 1: Go to Repository Settings**
1. Navigate to your GitHub repository
2. Click **Settings** tab
3. Click **Secrets and variables** → **Actions**

### **Step 2: Add Each Secret**
1. Click **New repository secret**
2. Enter the secret name (exactly as shown above)
3. Paste the secret value
4. Click **Add secret**

### **Step 3: Verify Secret Names**
Double-check that secret names match exactly:
- ✅ `APP_STORE_CONNECT_API_KEY_ID`
- ✅ `APP_STORE_CONNECT_ISSUER_ID`
- ✅ `APP_STORE_CONNECT_PRIVATE_KEY`
- ✅ `DISTRIBUTION_CERTIFICATE_BASE64`
- ✅ `DISTRIBUTION_P12_PASSWORD`
- ✅ `DISTRIBUTION_PROVISION_PROFILE_BASE64`
- ✅ `TEAM_ID`
- ✅ `KEYCHAIN_PASSWORD`

## 📋 App Store Connect API Key Setup

### **Step 1: Create API Key**
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **Users and Access** → **Integrations** → **API Keys**
3. Click **Generate API Key** or **+**
4. Enter a name: `GitHub Actions Deploy`
5. Select **App Manager** role
6. Click **Generate**

### **Step 2: Download and Configure**
1. **Download the .p8 file** immediately (you can only download once!)
2. **Copy the Key ID** (shown in the API Keys list)
3. **Copy the Issuer ID** (shown at the top of the API Keys page)
4. **Open the .p8 file** in a text editor and copy the entire contents

### **Step 3: API Key Permissions**
Make sure your API key has the **App Manager** role to upload builds.

## 🏗️ Code Signing Setup

### **Step 1: Export Certificates**
1. Open **Keychain Access** on your Mac
2. Find your **Apple Distribution** certificate
3. Right-click → **Export** → Choose .p12 format
4. Set a strong password
5. Save the file

### **Step 2: Download Provisioning Profile**
1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles** → **Profiles**
3. Find your **App Store** provisioning profile for the app
4. Click **Download**

### **Step 3: Encode Files**
```bash
# Encode certificate
base64 -i YourDistributionCert.p12 -o cert_encoded.txt

# Encode provisioning profile  
base64 -i YourAppStoreProfile.mobileprovision -o profile_encoded.txt
```

## 🔍 Troubleshooting

### **Common Issues:**

#### **"Failed to load AuthKey file"**
- ✅ Check `APP_STORE_CONNECT_PRIVATE_KEY` includes full .p8 file content
- ✅ Verify `APP_STORE_CONNECT_API_KEY_ID` matches your API key ID
- ✅ Ensure no extra spaces or characters in the secret

#### **"Authentication failed"**
- ✅ Verify `APP_STORE_CONNECT_ISSUER_ID` is correct
- ✅ Check that API key has **App Manager** role
- ✅ Ensure API key is not revoked or expired

#### **"Code signing failed"**
- ✅ Check `TEAM_ID` matches your Apple Developer Team ID
- ✅ Verify certificate is valid and not expired
- ✅ Ensure provisioning profile matches bundle identifier

#### **"Provisioning profile not found"**
- ✅ Verify provisioning profile includes your bundle ID
- ✅ Check that profile is for **App Store** distribution
- ✅ Ensure profile includes necessary capabilities (HealthKit)

### **Testing Secrets:**
You can test your setup by running the workflow manually:
1. Go to **Actions** tab in your repository
2. Click **Deploy to App Store** workflow
3. Click **Run workflow** → **Run workflow**
4. Monitor the build logs for any errors

## 📱 Bundle Identifier Configuration

Make sure your bundle identifier matches across:
- ✅ Xcode project: `com.amnesic.dev.healthexporter`
- ✅ App Store Connect app
- ✅ Provisioning profile
- ✅ GitHub Actions workflow

## 🎯 Success Checklist

Before running the workflow:
- [ ] All 8 required secrets are configured
- [ ] API key has App Manager role
- [ ] Distribution certificate is valid
- [ ] Provisioning profile matches bundle ID
- [ ] Team ID is correct
- [ ] App exists in App Store Connect
- [ ] Bundle identifier matches everywhere

## 📞 Getting Help

If you encounter issues:
1. Check the GitHub Actions build logs
2. Verify all secret values are correct
3. Test certificates and profiles locally first
4. Ensure App Store Connect app is properly configured

The workflow includes detailed error messages and troubleshooting hints to help identify issues quickly.