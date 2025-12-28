import Foundation

// ============================================
// User Model - Updated for Algorithm Overhaul
// ============================================

struct User: Codable, Identifiable, Equatable {
    let id: String
    var email: String
    var firstName: String?
    var lastName: String?
    var displayName: String?
    var avatarUrl: String?
    var subscriptionStatus: SubscriptionStatus
    var trialEndsAt: Date?
    var unitPreference: UnitPreference
    var isPrivate: Bool
    
    // New fields from Algorithm Overhaul
    var onboardingStatus: OnboardingStatus
    var trainingVolumeTier: Int // 1 = Light, 2 = Moderate, 3 = High
    var calibrationMethod: CalibrationMethod
    var dateOfBirth: Date?
    var gender: Gender?
    var primaryRaceId: String?
    
    // Biometrics (moved to separate table, but kept for convenience)
    var biometrics: Biometrics?
    
    // Legacy fields (kept for backwards compatibility)
    var experienceLevel: ExperienceLevel?
    var goalDistance: Constants.RaceDistance?
    var hasHeartRateMonitor: Bool
    
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case subscriptionStatus = "subscription_status"
        case trialEndsAt = "trial_ends_at"
        case unitPreference = "unit_preference"
        case isPrivate = "is_private"
        case onboardingStatus = "onboarding_status"
        case trainingVolumeTier = "training_volume_tier"
        case calibrationMethod = "calibration_method"
        case dateOfBirth = "dob"
        case gender
        case primaryRaceId = "primary_race_id"
        case biometrics
        case experienceLevel = "experience_level"
        case goalDistance = "goal_distance"
        case hasHeartRateMonitor = "has_heart_rate_monitor"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Computed Properties
    
    var displayNameOrEmail: String {
        displayName ?? firstName ?? email.components(separatedBy: "@").first ?? "Athlete"
    }
    
    var initials: String {
        if let name = displayName ?? firstName, let first = name.first {
            return String(first).uppercased()
        }
        return email.first.map { String($0).uppercased() } ?? "A"
    }
    
    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }
    
    var calculatedMaxHR: Int? {
        // Use biometrics maxHR if available, otherwise calculate from age
        if let maxHR = biometrics?.maxHeartRate {
            return maxHR
        }
        guard let age = age else { return nil }
        return 220 - age
    }
    
    var trialDaysRemaining: Int? {
        guard subscriptionStatus == .trial, let trialEndsAt = trialEndsAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: trialEndsAt).day ?? 0
        return max(0, days)
    }
    
    var hasAccess: Bool {
        switch subscriptionStatus {
        case .active:
            return true
        case .trial:
            return isTrialActive
        case .churned, .pastDue:
            return false
        }
    }
    
    var isTrialActive: Bool {
        guard subscriptionStatus == .trial else { return false }
        guard let trialEndsAt = trialEndsAt else { return true }
        return Date() < trialEndsAt
    }
    
    var isTrialExpired: Bool {
        guard subscriptionStatus == .trial else { return false }
        guard let trialEndsAt = trialEndsAt else { return false }
        return Date() >= trialEndsAt
    }
    
    var needsCalibration: Bool {
        calibrationMethod == .calibrationWeek && onboardingStatus == .biometricsPending
    }
    
    var hasBiometrics: Bool {
        guard let bio = biometrics else { return false }
        return bio.criticalSwimSpeed != nil || 
               bio.functionalThresholdPower != nil || 
               bio.thresholdRunPace != nil
    }
    
    // MARK: - Volume Tier Display
    
    var volumeTierDescription: String {
        switch trainingVolumeTier {
        case 1: return "Light (4-6 hrs/week)"
        case 2: return "Moderate (7-10 hrs/week)"
        case 3: return "High (11+ hrs/week)"
        default: return "Custom"
        }
    }
    
    // MARK: - Dev User
    
    static var devUser: User {
        User(
            id: "dev-user-001",
            email: "dev@trione.app",
            firstName: "Dev",
            lastName: "User",
            displayName: "Dev User",
            avatarUrl: nil,
            subscriptionStatus: .trial,
            trialEndsAt: Calendar.current.date(byAdding: .day, value: 14, to: Date()),
            unitPreference: .imperial,
            isPrivate: false,
            onboardingStatus: .completed,
            trainingVolumeTier: 2,
            calibrationMethod: .manualInput,
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -30, to: Date()),
            gender: .male,
            primaryRaceId: nil,
            biometrics: Biometrics(
                userId: "dev-user-001",
                heightCm: 178,
                weightKg: 75.0,
                maxHeartRate: 190,
                restingHeartRate: 55,
                criticalSwimSpeed: 95, // 1:35/100m
                functionalThresholdPower: 250,
                thresholdRunPace: 480 // 8:00/mile
            ),
            experienceLevel: .competitor,
            goalDistance: .olympic,
            hasHeartRateMonitor: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

// ============================================
// Biometrics Model (The Engine Scalars)
// ============================================

struct Biometrics: Codable, Equatable {
    var userId: String
    var heightCm: Int?
    var weightKg: Double?
    var maxHeartRate: Int?
    var restingHeartRate: Int?
    var criticalSwimSpeed: Double? // seconds per 100m
    var functionalThresholdPower: Int? // watts (FTP)
    var thresholdRunPace: Int? // seconds per mile
    var recordedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case maxHeartRate = "max_heart_rate"
        case restingHeartRate = "resting_heart_rate"
        case criticalSwimSpeed = "critical_swim_speed"
        case functionalThresholdPower = "functional_threshold_power"
        case thresholdRunPace = "threshold_run_pace"
        case recordedAt = "recorded_at"
    }
    
    // MARK: - Formatted Values
    
    var formattedCSS: String? {
        guard let css = criticalSwimSpeed else { return nil }
        let minutes = Int(css) / 60
        let seconds = Int(css) % 60
        return String(format: "%d:%02d/100m", minutes, seconds)
    }
    
    var formattedThresholdPace: String? {
        guard let pace = thresholdRunPace else { return nil }
        let minutes = pace / 60
        let seconds = pace % 60
        return String(format: "%d:%02d/mi", minutes, seconds)
    }
    
    var formattedFTP: String? {
        guard let ftp = functionalThresholdPower else { return nil }
        return "\(ftp)W"
    }
    
    var wattsPerKg: Double? {
        guard let ftp = functionalThresholdPower, let weight = weightKg, weight > 0 else {
            return nil
        }
        return Double(ftp) / weight
    }
    
    var formattedWattsPerKg: String? {
        guard let wpk = wattsPerKg else { return nil }
        return String(format: "%.2f W/kg", wpk)
    }
}

// ============================================
// Enums
// ============================================

enum OnboardingStatus: String, Codable {
    case started = "STARTED"
    case biometricsPending = "BIOMETRICS_PENDING"
    case completed = "COMPLETED"
}

enum CalibrationMethod: String, Codable {
    case manualInput = "MANUAL_INPUT"
    case calibrationWeek = "CALIBRATION_WEEK"
}

enum Gender: String, Codable, CaseIterable {
    case male = "MALE"
    case female = "FEMALE"
    case other = "OTHER"
    
    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        }
    }
}

enum ExperienceLevel: String, Codable, CaseIterable {
    case finisher = "finisher"
    case competitor = "competitor"
    
    var displayName: String {
        switch self {
        case .finisher: return "Finisher"
        case .competitor: return "Competitor"
        }
    }
    
    var description: String {
        switch self {
        case .finisher: return "I want to finish feeling strong"
        case .competitor: return "I want to compete for time/place"
        }
    }
    
    // Map to volume tier
    var volumeTier: Int {
        switch self {
        case .finisher: return 1
        case .competitor: return 3
        }
    }
}

enum SubscriptionStatus: String, Codable {
    case trial = "trial"
    case active = "active"
    case churned = "churned"
    case pastDue = "past_due"
}

enum UnitPreference: String, Codable, CaseIterable {
    case imperial = "imperial"
    case metric = "metric"
    
    var displayName: String {
        switch self {
        case .imperial: return "Imperial"
        case .metric: return "Metric"
        }
    }
    
    var description: String {
        switch self {
        case .imperial: return "Miles, yards, °F"
        case .metric: return "Kilometers, meters, °C"
        }
    }
}

// ============================================
// Heart Rate Zones
// ============================================

struct HeartRateZone: Codable, Identifiable {
    let id: String
    let userId: String
    let zoneNumber: Int
    let minHR: Int
    let maxHR: Int
    let calculationMethod: HRCalculationMethod
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case zoneNumber = "zone_number"
        case minHR = "min_hr"
        case maxHR = "max_hr"
        case calculationMethod = "calculation_method"
    }
    
    var zoneName: String {
        switch zoneNumber {
        case 1: return "Recovery"
        case 2: return "Endurance"
        case 3: return "Tempo"
        case 4: return "Threshold"
        case 5: return "VO2 Max"
        default: return "Zone \(zoneNumber)"
        }
    }
    
    var range: String {
        "\(minHR)-\(maxHR) bpm"
    }
}

enum HRCalculationMethod: String, Codable {
    case standard = "STANDARD"
    case karvonen = "KARVONEN"
}
