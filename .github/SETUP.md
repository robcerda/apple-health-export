# GitHub Actions & App Store Setup Guide

This guide walks you through setting up automated builds and App Store deployment for Health Exporter.

## 🔧 Quick Setup Checklist

- [ ] GitHub repository secrets configured
- [ ] Apple Developer account set up
- [ ] Code signing certificates exported
- [ ] App Store Connect API key created
- [ ] First workflow run successful

## 📋 Required GitHub Secrets

Navigate to your repository → Settings → Secrets and variables → Actions, then add these secrets:

### Code Signing Certificates

#### `BUILD_CERTIFICATE_BASE64`
Your iOS Development certificate (for building/testing)
```bash
# Export from Keychain Access → Right-click certificate → Export
# Then convert to base64
base64 -i Certificates.p12 | pbcopy
```

#### `P12_PASSWORD` 
Password for the development certificate .p12 file

#### `DISTRIBUTION_CERTIFICATE_BASE64`
Your iOS Distribution certificate (for App Store)
```bash
base64 -i DistributionCertificate.p12 | pbcopy
```

#### `DISTRIBUTION_P12_PASSWORD`
Password for the distribution certificate .p12 file

### Provisioning Profiles

#### `BUILD_PROVISION_PROFILE_BASE64`
Development provisioning profile
```bash
# Download from Apple Developer → Certificates, Identifiers & Profiles
base64 -i HealthExporter_Development.mobileprovision | pbcopy
```

#### `DISTRIBUTION_PROVISION_PROFILE_BASE64`
App Store distribution provisioning profile
```bash
base64 -i HealthExporter_AppStore.mobileprovision | pbcopy
```

### App Store Connect API

#### `APP_STORE_CONNECT_API_KEY_ID`
API Key ID (e.g., `ABC123DEF4`)

#### `APP_STORE_CONNECT_ISSUER_ID`
Issuer ID (UUID format)

#### `APP_STORE_CONNECT_PRIVATE_KEY`
Contents of the .p8 API key file
```bash
cat AuthKey_ABC123DEF4.p8 | pbcopy
```

### Team & App Information

#### `TEAM_ID`
Your Apple Developer Team ID (found in Apple Developer account)

#### `KEYCHAIN_PASSWORD`
Any secure password for the temporary build keychain (e.g., `build123!`)

## 🍎 Apple Developer Setup

### 1. App Store Connect Setup

1. **Create App Record**:
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Apps → "+" → New App
   - Bundle ID: `com.yourname.healthexporter` (or your chosen ID)
   - SKU: `health-exporter`

2. **App Information**:
   - Privacy Policy URL: Link to your privacy policy
   - Category: Health & Fitness
   - Content Rights: Yes (health data export)

3. **Create API Key**:
   - Users and Access → Keys → App Store Connect API
   - "+" → Key Name: "GitHub Actions"
   - Access: Developer
   - Download the .p8 file

### 2. Certificates & Profiles

1. **Development Certificate**:
   - Apple Developer → Certificates → "+"
   - iOS App Development
   - Generate CSR from Keychain Access
   - Download and install

2. **Distribution Certificate**:
   - Apple Developer → Certificates → "+"
   - iOS Distribution
   - Generate CSR from Keychain Access
   - Download and install

3. **App IDs**:
   - Apple Developer → Identifiers → "+"
   - App IDs → App
   - Bundle ID: `com.yourname.healthexporter`
   - Capabilities: HealthKit

4. **Provisioning Profiles**:
   - Development profile for building/testing
   - App Store profile for distribution

## 🚀 Workflow Triggers

### Continuous Integration (ios-build.yml)
- **Push to main/develop**: Builds and tests
- **Pull requests**: Validates changes
- **Manual trigger**: On-demand builds

### App Store Deployment (app-store-deploy.yml)
- **Version tags**: `v1.0.0`, `v1.0.1`, etc.
- **Manual trigger**: Emergency releases

## 📱 Creating a Release

### 1. Prepare Release
```bash
# Update version in Xcode project
# Update CHANGELOG.md
# Commit changes
git add .
git commit -m "Prepare v1.0.0 release"
git push
```

### 2. Create Tag
```bash
git tag v1.0.0
git push origin v1.0.0
```

### 3. Monitor Deployment
- GitHub Actions tab → Watch workflow progress
- App Store Connect → TestFlight → Review build
- App Store Connect → App Store → Submit for Review

## 🔍 Troubleshooting

### Common Issues

#### "No signing certificate found"
- Verify certificate base64 encoding is correct
- Check certificate is not expired
- Ensure provisioning profile matches certificate

#### "Failed to export archive"
- Check Team ID matches Apple Developer account
- Verify provisioning profile includes all required capabilities
- Ensure bundle ID matches exactly

#### "API key authentication failed"
- Verify all three API key components are correct
- Check API key has App Manager or Developer access
- Ensure .p8 file content is copied exactly

### Build Logs
- GitHub Actions logs show detailed error messages
- Build artifacts are retained for 30 days
- Use Xcode Cloud for additional validation if needed

## 🔒 Security Best Practices

### Secrets Management
- Never commit certificates or keys to git
- Rotate API keys annually
- Use repository secrets (not environment variables)
- Limit API key permissions to minimum required

### Code Signing
- Use different certificates for development vs. distribution
- Keep certificate private keys secure
- Enable automatic provisioning profile management when possible

### Health Data Privacy
- All builds include privacy-focused linting
- Security scans check for hardcoded secrets
- Health data handling is automatically validated

## 📊 Monitoring

### Build Status
Add to your README.md:
```markdown
[![iOS Build](https://github.com/yourusername/apple-health-export/actions/workflows/ios-build.yml/badge.svg)](https://github.com/yourusername/apple-health-export/actions/workflows/ios-build.yml)
```

### Release Status
- GitHub Releases track App Store submissions
- Build numbers are automatically incremented
- App Store Connect provides submission status

## 🎯 Next Steps

1. **Configure all secrets** using the checklist above
2. **Test workflow** by pushing a small change to main
3. **Create first release** using version tag
4. **Monitor App Store Connect** for build processing
5. **Submit for review** once ready

## 💡 Pro Tips

- Test the workflow with a development build first
- Keep certificates up to date (they expire annually)
- Use descriptive commit messages for better release notes
- Enable email notifications for failed builds
- Consider using Xcode Cloud as a backup CI system

---

For questions or issues, check the [GitHub Issues](https://github.com/yourusername/apple-health-export/issues) or Apple Developer forums.