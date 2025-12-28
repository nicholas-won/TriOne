# TriOne - Adaptive Triathlon Training App

A personalized, adaptive triathlon training application that functions as an intelligent digital coach. Unlike competitors that act as static spreadsheets or data dumps, TriOne adapts your training plan based on consistency, fatigue, and life constraints.

**Core Value Proposition:** *"A training plan that changes when life happens."*

---

## Implementation Status

### ✅ Fully Implemented (28 features)

| Feature | Description | Location |
|---------|-------------|----------|
| **iOS Native App** | Full SwiftUI app for iOS 17+ | `ios/TriOne/` |
| **Backend API** | Node.js/Express/TypeScript REST API | `packages/api/` |
| **Database Schema** | Complete PostgreSQL schema with RLS | `supabase/migrations/` |
| **Supabase Auth Integration** | Full auth with Supabase Swift SDK | `ios/.../Services/SupabaseService.swift` |
| **User Onboarding** | 5-step flow: Goal → Race → Experience → Calibration → Hardware | `ios/.../Onboarding/` |
| **Dashboard** | Week calendar, today's workout, weekly summary | `ios/.../Dashboard/` |
| **Workout Detail View** | Structure, intensity chart, step-by-step breakdown | `ios/.../Workout/WorkoutDetailView.swift` |
| **Active Workout Mode** | Timer, haptic cues, pause/skip, progress bar | `ios/.../Workout/ActiveWorkoutView.swift` |
| **Workout Rating System** | Post-workout feedback: Easier/Same/Harder + RPE 1-10 | `ios/.../Workout/WorkoutFeedbackSheet.swift` |
| **Workout Completion Sync** | Marks workouts complete, persists to backend & local | `ios/.../Services/WorkoutService.swift` |
| **2-Strike Adaptation Engine** | Tracks fatigue strikes, auto-reduces intensity | `packages/api/src/engine/adaptationEngine.ts` |
| **Missed Workout Logic** | Priority-based rescheduling with safety limits | `packages/api/src/engine/adaptationEngine.ts` |
| **Calibration Week Generator** | Swim 400m, Run 1mi, Bike 20min tests | `packages/api/src/engine/calibrationWeek.ts` |
| **Training Plan Generator** | Phase-based: Base → Build → Peak → Taper | `packages/api/src/engine/planGenerator.ts` |
| **Workout Template System** | Master templates with user scalars | `packages/api/src/engine/workoutGenerator.ts` |
| **RevenueCat Subscriptions** | Real purchase flow with RevenueCat SDK | `ios/.../Services/SubscriptionService.swift` |
| **Trial Expiration Enforcement** | Blocks features when trial expires | `ios/.../App/AppState.swift` |
| **Push Notifications** | Workout reminders via APNs | `ios/.../Services/NotificationService.swift` |
| **Paywall UI** | 14-day trial, annual/monthly plan selection | `ios/.../Paywall/PaywallView.swift` |
| **Dev Mode** | Bypass auth, mock data, local persistence | Auth screens + `AuthService.swift` |
| **Haptic Feedback** | Countdown, success, interval transitions | `ios/.../Services/HapticService.swift` |
| **Theme System** | Consistent colors for swim/bike/run, typography | `ios/.../Core/Theme.swift` |
| **API Integration** | Full API service with all endpoints | `ios/.../Services/APIService.swift` |
| **Workout History** | Past activities with filtering and stats | `ios/.../Features/History/` |
| **Training Progress** | Phase visualization, week progress, race countdown | `ios/.../Dashboard/TrainingProgressView.swift` |
| **Calibration Results** | UI to enter swim/bike/run test results | `ios/.../Features/Calibration/` |
| **Statistics Dashboard** | Training metrics, PRs, and insights | `ios/.../Features/Stats/StatsView.swift` |
| **HealthKit Auto-Sync** | Automatic workout sync to Apple Health | `ios/.../Services/HealthKitService.swift` |

### ⚠️ Partially Implemented (6 features)

| Feature | What Works | What's Missing |
|---------|------------|----------------|
| **Social Feed** | UI complete with kudos, API routes exist | iOS uses mock data only, no friend search/add |
| **Race Management** | UI for viewing/adding races | Local state only, not synced to Supabase |
| **Baselines Update** | Profile UI for CSS/FTP/pace entry | Saves locally in dev mode, API call not tested |
| **HealthKit Integration** | Service with auth, read/write methods | No auto-sync after workouts complete |
| **Heart Rate Zones** | Profile settings UI | No calculation logic, no backend storage |
| **Privacy Toggle** | Toggle in profile UI | Doesn't persist to backend |

### ❌ Not Implemented (4 features)

| Feature | Priority | Notes |
|---------|----------|-------|
| **Apple Watch App** | 🟡 Medium | No watchOS target |
| **Garmin Connect** | 🟢 Low | UI shows "Not connected", no API |
| **Friend Search/Invite** | 🟢 Low | Social connections not implemented |
| **Social Sharing** | 🟢 Low | Share workouts to social media |

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| iOS App | Swift, SwiftUI (iOS 17+) |
| Auth | Supabase Auth (Swift SDK) |
| Subscriptions | RevenueCat |
| Backend | Node.js, Express, TypeScript |
| Database | Supabase (PostgreSQL + Auth) |
| Health Integration | HealthKit, CoreLocation |
| Haptics | CoreHaptics |
| Notifications | APNs (Local + Remote) |

## Project Structure

```
/TriOne
├── ios/                        # Native iOS App (Swift/SwiftUI)
│   ├── TriOne.xcodeproj       # Xcode project
│   ├── project.yml            # XcodeGen configuration
│   └── TriOne/
│       ├── App/               # Entry point, root views
│       │   ├── TriOneApp.swift
│       │   ├── ContentView.swift
│       │   └── AppState.swift
│       ├── Core/
│       │   ├── Config.swift   # Environment config
│       │   ├── Models/        # User, Workout, Race
│       │   ├── Services/      # Auth, API, Health, Haptics, Location
│       │   │   ├── AuthService.swift
│       │   │   ├── SupabaseService.swift
│       │   │   ├── APIService.swift
│       │   │   ├── SubscriptionService.swift
│       │   │   ├── NotificationService.swift
│       │   │   └── ...
│       │   └── Theme.swift    # Colors, styling
│       ├── Resources/
│       │   └── Config.plist   # API keys configuration
│       └── Features/
│           ├── Auth/          # Welcome, Login, Register
│           ├── Onboarding/    # 5-step setup flow
│           ├── Dashboard/     # Home screen with calendar
│           ├── Workout/       # Detail, Active mode, Feedback
│           ├── Races/         # Race management
│           ├── Social/        # Activity feed
│           ├── Profile/       # Settings & preferences
│           └── Paywall/       # Subscription screen
├── packages/
│   └── api/                   # Node.js backend
│       ├── src/
│       │   ├── routes/        # Express routes (8 route files)
│       │   ├── engine/        # Logic engine (adaptation, plans, calibration)
│       │   ├── middleware/    # Auth middleware
│       │   ├── db/            # Supabase client
│       │   └── seed/          # Seed data (templates, races)
│       └── package.json
├── supabase/
│   └── migrations/            # SQL migrations
└── package.json               # Backend monorepo root
```

## Getting Started

### Prerequisites

- macOS 14+ (Sonoma)
- Xcode 15+ (Xcode 16+ for iOS 26 devices)
- Node.js 18+
- Supabase account
- XcodeGen (`brew install xcodegen`)
- RevenueCat account (for subscriptions)

### Environment Setup

1. Clone the repository

2. Create a Supabase project at [supabase.com](https://supabase.com)

3. Create `packages/api/.env`:
```bash
SUPABASE_URL=your-supabase-url
SUPABASE_SERVICE_KEY=your-service-key
PORT=3001
```

4. Configure iOS app (`ios/TriOne/Resources/Config.plist`):
```xml
<dict>
    <key>SUPABASE_URL</key>
    <string>https://your-project.supabase.co</string>
    <key>SUPABASE_ANON_KEY</key>
    <string>your-anon-key</string>
    <key>API_BASE_URL</key>
    <string>http://localhost:3001</string>
    <key>REVENUECAT_API_KEY</key>
    <string>your-revenuecat-key</string>
</dict>
```

5. Run the database migration in Supabase SQL Editor:
   - Copy contents of `supabase/migrations/001_initial_schema.sql`
   - Run in Supabase SQL Editor

### Installation

#### Backend API

```bash
# Install dependencies
npm install

# Seed the database (workout templates & races)
npm run seed

# Start the API server
npm run dev:api
```

#### iOS App

```bash
# Navigate to iOS directory
cd ios

# Generate Xcode project (if needed)
xcodegen generate

# Resolve package dependencies
xcodebuild -resolvePackageDependencies -project TriOne.xcodeproj

# Open in Xcode
open TriOne.xcodeproj
```

Then in Xcode:
1. Select your development team in Signing & Capabilities
2. Choose a simulator or device
3. Press `Cmd + R` to build and run

### Configuration Required

Before the app will fully work, you need to configure:

1. **Supabase** - Create project and add URL/keys to `Config.plist`
2. **RevenueCat** - Create account, set up products, add API key to `Config.plist`
3. **Apple Push Notifications** - Enable in Xcode and App Store Connect (for production)
4. **Google Sign-In** - Already configured with client ID in `Info.plist`

### Dev Mode

The iOS app includes a "Dev Mode" that bypasses authentication and uses mock data:
- Look for the orange "🚧 DEV: Skip Authentication" button on auth screens
- Useful for UI development without running the backend
- Workout completions persist locally via UserDefaults
- Mock data generated for dashboard, workouts, races, and social feed

## Key Components

### 🧠 Proprietary Logic Engine (v2.0)

TriOne uses a **Dynamic Linked List of Workout Objects** with **Scalar Injection** - not static calendar events.

#### Core Formula
```
Target_Intensity = Template_Coefficient × User_Biometric_Scalar × Intensity_Scalar
```

#### The Biometric Scalars (Engine Inputs)
| Metric | Formula | Description |
|--------|---------|-------------|
| **CSS** | `(400m_time ÷ 4) + 3.0` | Critical Swim Speed (sec/100m) |
| **FTP** | `20min_avg_power × 0.95` | Functional Threshold Power (watts) |
| **Threshold Pace** | `1mile_time × 1.15` | Aerobic threshold (sec/mile) |
| **Max HR** | `220 - age` | Calculated if not provided |

#### Volume Tiers
| Tier | Weekly Hours | Swim | Bike | Run | Best For |
|------|--------------|------|------|-----|----------|
| 1 (Light) | 4-6 hrs | 1 | 1 | 1 | Finishers |
| 2 (Moderate) | 7-10 hrs | 2 | 2 | 2 | Improvers |
| 3 (High) | 11+ hrs | 3 | 3 | 3 | Competitors |

#### Training Phases
| Phase | Zone Focus | Intensity | Volume |
|-------|------------|-----------|--------|
| **BASE** | Zone 2 | 85% | 100% |
| **BUILD** | Zone 3/4 | 100% | 90% |
| **PEAK** | Zone 5 | 110% | 80% |
| **TAPER** | Zone 2/3 | 90% | 50% |

#### 2-Strike Adaptation Rule
The algorithm tracks fatigue and auto-adapts:

**Strike Triggers** (any = +1 strike):
- Subjective: User rates workout "Harder than expected"
- Objective: RPE > Target_RPE + 2
- Compliance: Skipped workout (reason: "Too tired" or "Sick")

**When Strikes ≥ 2:**
1. **Intensity Cut** - Next 2 interval sessions get 15% reduction
2. **Volume Conversion** - Next long workout becomes recovery (50% duration)
3. **Reset** - Strikes reset to 0, push notification sent

#### Priority Scheduler (Daily Cron)
Handles missed workouts at 00:01 each day:

| Gate | Condition | Action |
|------|-----------|--------|
| 1 | Missed = Priority 3 | DELETE (low value) |
| 2 | Missed < Today's Priority | SWAP (bump today's) |
| 3 | Both = Intervals | DELETE missed (safety) |

#### Heart Rate Zones
Two calculation methods:
- **Standard**: `Zone_HR = Max_HR × percentage`
- **Karvonen**: `Zone_HR = ((Max_HR - Resting_HR) × %) + Resting_HR`

#### Calibration Week
For users who choose "Test Me" instead of entering biometrics:
1. **Day 1** - 400m Swim Time Trial → CSS
2. **Day 3** - 20min Bike Test → FTP
3. **Day 5** - 1 Mile Run Time Trial → Threshold Pace
4. **Day 6-7** - Recovery sessions

### Subscription Flow

1. User completes onboarding
2. Paywall displays with 14-day trial offer
3. RevenueCat handles purchase/restore
4. Trial expiration checked on app launch and hourly
5. Expired trial shows paywall with "Subscribe" prompt
6. Active subscribers get full access

### Notification System

- **Daily Workout Reminders** - Configurable time in Profile settings
- **Upcoming Workout Alerts** - 30 minutes before scheduled workouts
- **Workout Completion** - Celebration notification
- **Trial Expiring** - Warning when trial is about to end

## API Endpoints

### User & Onboarding
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/users/me` | GET | Get current user profile (includes biometrics) |
| `/api/users/me` | PATCH | Update user profile |
| `/api/users/onboarding/complete` | POST | Complete onboarding with logic fork |
| `/api/users/activate-trial` | POST | Activate free trial |
| `/api/users/heart-rate-zones` | GET | Get user's HR zones |

### Workouts
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/workouts` | GET | Get workouts by date range |
| `/api/workouts/today` | GET | Get today's workout |
| `/api/workouts/week` | GET | Get week's workouts |
| `/api/workouts/:id` | GET | Get workout by ID |
| `/api/workouts/:id/complete` | POST | Complete a workout |
| `/api/workouts/:id/skip` | POST | Skip a workout (with reason) |
| `/api/feedback` | POST | Submit workout feedback (triggers 2-strike check) |

### Training Plans
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/plans` | POST | Create training plan |
| `/api/plans/active` | GET | Get active training plan |
| `/api/calibration/result` | POST | Submit calibration test result |

### Biometrics & Races
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/biometrics/current` | GET | Get current biometrics |
| `/api/biometrics` | POST | Update biometrics |
| `/api/races` | GET | Get all races |
| `/api/races/:id` | GET | Get race by ID |

### Social
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/social/feed` | GET | Get social activity feed |
| `/api/social/kudos/:id` | POST | Give kudos |
| `/api/social/kudos/:id` | DELETE | Remove kudos |
| `/api/social/friends` | GET | Get friends list |
| `/api/social/friends/:id` | POST | Add friend |

## Roadmap

### ~~Phase 1: Production MVP~~ ✅ Complete
- [x] Supabase authentication integration in iOS
- [x] Full API integration (replace all mock data)
- [x] RevenueCat subscription management
- [x] Trial expiration enforcement
- [x] Push notifications (workout reminders)

### ~~Phase 2: Core Experience~~ ✅ Complete
- [x] Workout history view
- [x] Training progress visualization (phase, week, countdown)
- [x] Calibration test result input UI
- [x] Statistics/analytics dashboard
- [x] HealthKit auto-sync after workouts

### Phase 3: Expansion
- [ ] Apple Watch companion app
- [ ] Garmin Connect integration
- [ ] Friend search & invite
- [ ] Social sharing

## Design System

| Element | Value |
|---------|-------|
| Primary Accent | #71c7ec (Cerulean) |
| Background | #FFFFFF (White) |
| Active Mode BG | #000000 (Black) |
| Swim | #0EA5E9 (Sky Blue) |
| Bike | #F97316 (Orange) |
| Run | #22C55E (Green) |
| Strength | #8B5CF6 (Purple) |
| Brick | #EC4899 (Pink) |
| Success | #22C55E (Green) |
| Error | #EF4444 (Red) |
| Warning | #F59E0B (Amber) |

## Database Schema

Key tables:
- `users` - User profiles and subscription status
- `biometrics` - CSS, FTP, threshold pace
- `training_plans` - User training plans with race date
- `workouts` - Scheduled workouts with structure
- `activity_logs` - Completed workout data
- `feedback_logs` - Workout feedback (rating + RPE)
- `user_training_state` - Fatigue strikes, training load
- `races` - Official and custom races
- `friendships` - Social connections
- `kudos` - Activity kudos

## License

Proprietary - All rights reserved

## Support

For support, please contact the development team.
