# User Setup Tasks

These are tasks that require manual configuration that cannot be done programmatically.

---

## 🔴 Critical (Required for App to Work)

### 1. ✅ Accept Xcode License (COMPLETED)
Run this command in Terminal:
```bash
sudo xcodebuild -license accept
```

### 2. ✅ Configure Supabase (COMPLETED)
1. Create a project at [supabase.com](https://supabase.com)
2. Run the database migration:
   - Go to SQL Editor in Supabase dashboard
   - Copy contents of `supabase/migrations/001_initial_schema.sql`
   - Execute the SQL
3. Get your credentials from Settings → API:
   - **Project URL** (e.g., `https://xxxxx.supabase.co`)
   - **anon public key** (starts with `eyJ...`)
4. Update `ios/TriOne/Resources/Config.plist`:
   ```xml
   <key>SUPABASE_URL</key>
   <string>https://your-project.supabase.co</string>
   <key>SUPABASE_ANON_KEY</key>
   <string>your-anon-key-here</string>
   ```
5. Update `packages/api/.env`:
   ```bash
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_SERVICE_KEY=your-service-role-key
   PORT=3001
   ```

### 3. ⚠️ Configure RevenueCat (for Subscriptions) (NEEDS PUBLIC KEY)
1. Create account at [revenuecat.com](https://www.revenuecat.com)
2. Create a new project
3. Add your app (iOS)
4. Create products in App Store Connect:
   - `trione_monthly` - Monthly subscription ($9.99/month)
   - `trione_annual` - Annual subscription ($79.99/year)
5. Add the products to RevenueCat
6. Create an "Offering" with both packages
7. Create an "Entitlement" called `premium`
8. **IMPORTANT**: Get your **PUBLIC API KEY** (NOT the secret key):
   - Go to Project Settings → API Keys
   - Copy the **Public API Key** (starts with `rc_`, `appl_`, or `goog_`)
   - ⚠️ Do NOT use the Secret Key (starts with `sk_`) - that's for backend only!
9. Update `ios/TriOne/Resources/Config.plist`:
   ```xml
   <key>REVENUECAT_API_KEY</key>
   <string>your-public-api-key-here</string>
   ```

### 4. ✅ Set Development Team in Xcode (COMPLETED)
1. Open `ios/TriOne.xcodeproj` in Xcode
2. Select the TriOne target
3. Go to Signing & Capabilities
4. Select your Apple Developer Team
5. Fix any bundle identifier conflicts if needed

---

## 🟠 High Priority (Required for Full Functionality)

### 5. ✅ Configure Google Sign-In (COMPLETED)
The client ID is already configured. To complete setup:
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create OAuth 2.0 credentials for iOS
3. Add your app's bundle ID (`com.trione.app`)
4. The URL scheme is already in `Info.plist`

### 6. Configure Apple Sign-In (Requires Paid Developer Account)
1. Requires Apple Developer Program membership ($99/year)
2. In Apple Developer portal:
   - Go to Certificates, Identifiers & Profiles
   - Select your App ID
   - Enable "Sign in with Apple" capability
3. In Xcode, add the capability:
   - Select target → Signing & Capabilities
   - Click "+ Capability"
   - Add "Sign in with Apple"
4. Uncomment in `ios/TriOne/TriOne.entitlements`:
   ```xml
   <key>com.apple.developer.applesignin</key>
   <array>
       <string>Default</string>
   </array>
   ```

### 7. Configure Push Notifications (Requires Paid Developer Account)
1. In Apple Developer portal:
   - Go to Certificates, Identifiers & Profiles
   - Create an APNs Key (or Certificate)
2. In Xcode, add the capability:
   - Select target → Signing & Capabilities
   - Click "+ Capability"
   - Add "Push Notifications"
3. Add APNs key to RevenueCat (for subscription notifications)
4. Update entitlements for production:
   ```xml
   <key>aps-environment</key>
   <string>production</string>
   ```

---

## 🟡 Medium Priority (Nice to Have)

### 8. ✅ Run Database Migration (COMPLETED)
After Supabase is configured, apply the schema migrations:
```bash
# In Supabase Dashboard -> SQL Editor
# Run: supabase/migrations/001_initial_schema.sql
# Then: supabase/migrations/002_algorithm_overhaul.sql
```
This creates:
- Users table with onboarding fields
- Biometrics table (CSS, FTP, Threshold Pace)
- Volume tier configuration
- Training phase configuration
- Heart rate zones table
- Adaptation logs

### 9. ✅ Seed the Database (COMPLETED)
After migrations are applied:
```bash
cd /Users/Nick/TriOne
npm install
npm run seed
```
This populates:
- Workout templates
- Sample races
- Volume tier defaults

### 10. Configure App Store Connect (for TestFlight/Release)
1. Create app in App Store Connect
2. Set up In-App Purchases:
   - Monthly subscription
   - Annual subscription
3. Configure subscription group
4. Submit for review

### 11. Set Up Backend Hosting
Options:
- **Vercel** - Easy deploy for Node.js
- **Railway** - Simple hosting
- **Render** - Free tier available
- **AWS/GCP** - More control

Update `ios/TriOne/Resources/Config.plist` with production URL:
```xml
<key>API_BASE_URL</key>
<string>https://your-api.example.com</string>
```

---

## 🟢 Low Priority (Future Enhancements)

### 12. Garmin Connect Integration
- Apply for Garmin Connect API access
- Set up OAuth flow
- Store credentials securely

### 13. Apple Watch App
- Add watchOS target in Xcode
- Configure Watch App capabilities
- Set up HealthKit sharing

### 14. Analytics Setup
Consider adding:
- **Mixpanel** or **Amplitude** for product analytics
- **Sentry** or **Bugsnag** for crash reporting
- **Firebase Analytics** for user behavior

---

## Configuration Files Reference

| File | Purpose |
|------|---------|
| `ios/TriOne/Resources/Config.plist` | iOS app configuration |
| `packages/api/.env` | Backend API environment variables |
| `ios/TriOne/Info.plist` | iOS app metadata |
| `ios/TriOne/TriOne.entitlements` | iOS app capabilities |
| `ios/project.yml` | XcodeGen project definition |

---

## Quick Start Checklist

- [x] Run `sudo xcodebuild -license accept`
- [x] Create Supabase project
- [x] Run database migration
- [x] Update `Config.plist` with Supabase credentials
- [x] Update `packages/api/.env` with Supabase credentials
- [x] Create RevenueCat account and project
- [x] Add RevenueCat API key to `Config.plist`
- [x] Set development team in Xcode
- [x] Run `npm install && npm run seed`
- [ ] Build and run!

---

## Troubleshooting

### "No such module 'Supabase'" error
```bash
cd ios
xcodebuild -resolvePackageDependencies -project TriOne.xcodeproj
```

### Signing issues
- Make sure you've selected a development team
- Try: Product → Clean Build Folder (Cmd+Shift+K)

### Push notifications not working
- Requires paid Apple Developer account
- Check entitlements file has correct `aps-environment`
- Verify APNs key is configured in RevenueCat

### RevenueCat not showing products
- Verify products are created in App Store Connect
- Check products are added to RevenueCat offerings
- Make sure you're using the correct API key

