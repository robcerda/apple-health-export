# App Store Connect Privacy Questionnaire Guide
## Health Data Exporter

This guide helps you answer Apple's App Store Connect privacy questions accurately.

---

## Data Collection Questions

### Do you or your third-party partners collect data from this app?
**Answer**: ❌ **No**

### Does this app use the Advertising Identifier (IDFA)?
**Answer**: ❌ **No**

### Does this app collect user data?
**Answer**: ❌ **No**

*Even though the app accesses health data, it doesn't "collect" it in Apple's definition since it only processes it locally and doesn't retain or transmit it.*

---

## Health Data Questions

### Does your app access HealthKit data?
**Answer**: ✅ **Yes**

### What types of health data does your app access?
**Select all that apply:**
- ✅ Body Measurements (height, weight, BMI, etc.)
- ✅ Fitness (steps, distance, calories, workouts)
- ✅ Health Records (various health metrics)
- ✅ Heart (heart rate, heart rate variability)
- ✅ Mobility (walking speed, step length, etc.)
- ✅ Nutrition (dietary information if available)
- ✅ Reproductive Health (if applicable)
- ✅ Respiratory (respiratory rate, etc.)
- ✅ Sleep (sleep analysis data)
- ✅ Vital Signs (blood pressure, temperature, etc.)

### How do you use HealthKit data?
**Answer**: 
- ✅ Export health data for user's personal use
- ❌ NOT used for advertising
- ❌ NOT used for analytics  
- ❌ NOT shared with third parties
- ❌ NOT used for app functionality beyond export

### Do you share HealthKit data with third parties?
**Answer**: ❌ **No**

---

## Specific Data Type Questions

*For each data type Apple asks about, answer:*

### Contact Info
**Collect**: ❌ No

### Health & Fitness  
**Collect**: ✅ Yes (HealthKit access only)
**Usage**: Other (Export for user's personal use)
**Tracking**: ❌ No
**Third-party sharing**: ❌ No

### Financial Info
**Collect**: ❌ No

### Location
**Collect**: ❌ No

### Sensitive Info
**Collect**: ❌ No

### Contacts
**Collect**: ❌ No

### User Content
**Collect**: ❌ No

### Browsing History
**Collect**: ❌ No

### Search History
**Collect**: ❌ No

### Identifiers
**Collect**: ❌ No

### Usage Data
**Collect**: ❌ No

### Diagnostics
**Collect**: ❌ No

---

## Privacy Policy URL

**Provide one of these URLs:**
- Use the GitHub repository URL with the privacy policy
- Host the `PRIVACY_POLICY_WEB.md` file on a website
- Example: `https://github.com/yourusername/health-data-exporter/blob/main/PRIVACY.md`

---

## Additional Notes

### App Store Review Notes
*Include this text in your app review notes:*

"This app accesses HealthKit data solely for local export functionality. No data is collected, stored, or transmitted. All processing occurs on-device. The app makes zero network requests and contains no third-party SDKs. Users maintain complete control over their health data through iOS permissions and can export it in encrypted or unencrypted formats."

### Age Rating
- **Minimum Age**: 4+ (no content issues)
- **Medical/Treatment Info**: Yes (processes health data)
- **Unrestricted Web Access**: No

### Keywords for App Store
- health data export
- healthkit export  
- privacy health
- personal health data
- medical records export
- health backup
- health data backup
- fitness data export

---

## Required Disclosures

### Data Not Collected
Emphasize that you:
- Don't collect personal information
- Don't use analytics or tracking
- Don't share data with third parties
- Don't require user accounts
- Don't access internet/network

### User Control
Highlight that users:
- Control which health data is accessed
- Can encrypt export files
- Can delete data anytime
- Can revoke permissions anytime
- Own all export files created

### Transparency
Mention:
- Open-source code available for review
- No hidden functionality
- Complete privacy policy available
- Verifiable privacy claims