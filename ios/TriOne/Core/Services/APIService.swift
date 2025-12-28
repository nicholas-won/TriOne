import Foundation

@MainActor
class APIService: ObservableObject {
    static let shared = APIService()
    
    private var baseURL: String {
        Config.apiBaseURL
    }
    private var authToken: String?
    
    private init() {}
    
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }
    
    // MARK: - User Endpoints
    
    func getUserProfile() async throws -> Data {
        return try await get(endpoint: "/api/users/me")
    }
    
    func updateUserProfile(user: User) async throws {
        let body: [String: Any] = [
            "display_name": user.displayName ?? "",
            "unit_preference": user.unitPreference.rawValue,
            "is_private": user.isPrivate
        ]
        _ = try await patch(endpoint: "/api/users/me", body: body)
    }
    
    func updatePrimaryRace(raceId: String?) async throws {
        var body: [String: Any] = [:]
        if let raceId = raceId {
            body["primary_race_id"] = raceId
        } else {
            body["primary_race_id"] = NSNull()
        }
        _ = try await patch(endpoint: "/api/users/me", body: body)
    }
    
    func completeOnboarding(
        goalDistance: String,
        raceId: String?,
        experienceLevel: String,
        swimPace: Any, // Int or "unknown"
        runPace: Any,
        bikeFtp: Any,
        hasHeartRateMonitor: Bool,
        unitPreference: String
    ) async throws -> OnboardingResponse {
        var body: [String: Any] = [
            "goal_distance": goalDistance,
            "experience_level": experienceLevel,
            "swim_pace": swimPace,
            "run_pace": runPace,
            "bike_ftp": bikeFtp,
            "has_heart_rate_monitor": hasHeartRateMonitor,
            "unit_preference": unitPreference
        ]
        
        if let raceId = raceId {
            body["race_id"] = raceId
        }
        
        let data = try await post(endpoint: "/api/users/onboarding", body: body)
        return try JSONDecoder().decode(OnboardingResponse.self, from: data)
    }
    
    func activateTrial() async throws -> UserResponse {
        let data = try await post(endpoint: "/api/users/activate-trial", body: [:])
        return try JSONDecoder().decode(UserResponse.self, from: data)
    }
    
    // MARK: - Biometrics Endpoints
    
    func getCurrentBiometrics() async throws -> BiometricsResponse {
        let data = try await get(endpoint: "/api/biometrics/current")
        return try JSONDecoder().decode(BiometricsResponse.self, from: data)
    }
    
    func updateBiometrics(
        swimPace: Int?,
        runPace: Int?,
        bikeFtp: Int?,
        maxHeartRate: Int?,
        restingHeartRate: Int?
    ) async throws -> BiometricsResponse {
        var body: [String: Any] = [:]
        
        if let swimPace = swimPace { body["css_pace_per_100"] = swimPace }
        if let runPace = runPace { body["run_threshold_pace_per_mile"] = runPace }
        if let bikeFtp = bikeFtp { body["bike_ftp"] = bikeFtp }
        if let maxHeartRate = maxHeartRate { body["max_heart_rate"] = maxHeartRate }
        if let restingHeartRate = restingHeartRate { body["resting_heart_rate"] = restingHeartRate }
        
        let data = try await post(endpoint: "/api/biometrics", body: body)
        return try JSONDecoder().decode(BiometricsResponse.self, from: data)
    }
    
    // MARK: - Race Endpoints
    
    func fetchRaces() async throws -> [RaceResponse] {
        let data = try await get(endpoint: "/api/races")
        return try JSONDecoder().decode([RaceResponse].self, from: data)
    }
    
    func fetchRace(id: String) async throws -> RaceResponse {
        let data = try await get(endpoint: "/api/races/\(id)")
        return try JSONDecoder().decode(RaceResponse.self, from: data)
    }
    
    // MARK: - Plan Endpoints
    
    func getActivePlan() async throws -> PlanResponse? {
        let data = try await get(endpoint: "/api/plans/active")
        
        // Handle null response
        if let _ = try? JSONSerialization.jsonObject(with: data) as? NSNull {
            return nil
        }
        
        return try JSONDecoder().decode(PlanResponse.self, from: data)
    }
    
    func fetchActivePlan() async throws -> PlanResponse? {
        return try await getActivePlan()
    }
    
    // MARK: - Social Endpoints
    
    func fetchSocialFeed(page: Int = 1) async throws -> SocialFeedResponse {
        let data = try await get(endpoint: "/api/social/feed?page=\(page)")
        return try JSONDecoder().decode(SocialFeedResponse.self, from: data)
    }
    
    func giveKudos(activityLogId: String) async throws {
        _ = try await post(endpoint: "/api/social/kudos/\(activityLogId)", body: [:])
    }
    
    func removeKudos(activityLogId: String) async throws {
        _ = try await delete(endpoint: "/api/social/kudos/\(activityLogId)")
    }
    
    func fetchFriends() async throws -> [FriendResponse] {
        let data = try await get(endpoint: "/api/social/friends")
        return try JSONDecoder().decode([FriendResponse].self, from: data)
    }
    
    // MARK: - Workout Endpoints
    
    func completeWorkout(
        workoutId: String,
        duration: Int,
        distance: Int? = nil,
        avgHeartRate: Int? = nil
    ) async throws -> ActivityLog {
        let endpoint = "/api/workouts/\(workoutId)/complete"
        
        var body: [String: Any] = [
            "total_duration_seconds": duration,
            "source": "active_mode_recording"
        ]
        
        if let distance = distance {
            body["total_distance_meters"] = distance
        }
        if let avgHeartRate = avgHeartRate {
            body["avg_heart_rate"] = avgHeartRate
        }
        
        let data = try await post(endpoint: endpoint, body: body)
        return try JSONDecoder().decode(ActivityLog.self, from: data)
    }
    
    func skipWorkout(workoutId: String) async throws {
        let endpoint = "/api/workouts/\(workoutId)/skip"
        _ = try await post(endpoint: endpoint, body: [:])
    }
    
    func submitFeedback(
        activityLogId: String,
        rating: String,
        rpe: Int?
    ) async throws -> FeedbackLog {
        let endpoint = "/api/feedback"
        
        var body: [String: Any] = [
            "activity_log_id": activityLogId,
            "rating": rating
        ]
        
        if let rpe = rpe {
            body["rpe"] = rpe
        }
        
        let data = try await post(endpoint: endpoint, body: body)
        return try JSONDecoder().decode(FeedbackLog.self, from: data)
    }
    
    func fetchTodayWorkout() async throws -> WorkoutResponse? {
        let endpoint = "/api/workouts/today"
        let data = try await get(endpoint: endpoint)
        
        // Handle null response
        if let json = try? JSONSerialization.jsonObject(with: data) as? NSNull {
            return nil
        }
        
        return try JSONDecoder().decode(WorkoutResponse.self, from: data)
    }
    
    func fetchWeekWorkouts(date: Date? = nil) async throws -> [WorkoutResponse] {
        var endpoint = "/api/workouts/week"
        if let date = date {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            endpoint += "?date=\(formatter.string(from: date))"
        }
        
        let data = try await get(endpoint: endpoint)
        return try JSONDecoder().decode([WorkoutResponse].self, from: data)
    }
    
    func fetchWorkouts(startDate: Date, endDate: Date) async throws -> [WorkoutResponse] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let startString = formatter.string(from: startDate)
        let endString = formatter.string(from: endDate)
        
        let endpoint = "/api/workouts?start=\(startString)&end=\(endString)"
        let data = try await get(endpoint: endpoint)
        return try JSONDecoder().decode([WorkoutResponse].self, from: data)
    }
    
    // MARK: - HTTP Methods
    
    private func get(endpoint: String) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addHeaders(to: &request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return data
    }
    
    private func post(endpoint: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        addHeaders(to: &request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return data
    }
    
    private func patch(endpoint: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        addHeaders(to: &request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return data
    }
    
    private func delete(endpoint: String) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addHeaders(to: &request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response)
        return data
    }
    
    private func addHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.unknown(httpResponse.statusCode)
        }
    }
}

// MARK: - API Response Models

struct ActivityLog: Codable {
    let id: String
    let workoutId: String
    let userId: String
    let completedAt: String
    let totalDurationSeconds: Int
    let totalDistanceMeters: Int?
    let avgHeartRate: Int?
    let source: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case workoutId = "workout_id"
        case userId = "user_id"
        case completedAt = "completed_at"
        case totalDurationSeconds = "total_duration_seconds"
        case totalDistanceMeters = "total_distance_meters"
        case avgHeartRate = "avg_heart_rate"
        case source
    }
}

struct FeedbackLog: Codable {
    let id: String
    let activityLogId: String
    let feedbackRating: String
    let rpeScore: Int?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case activityLogId = "activity_log_id"
        case feedbackRating = "feedback_rating"
        case rpeScore = "rpe_score"
        case createdAt = "created_at"
    }
}

struct WorkoutResponse: Codable {
    let id: String
    let planId: String
    let templateId: String?
    let scheduledDate: String
    let workoutType: String
    let priorityLevel: Int
    let status: String
    let isCalibrationTest: Bool
    let calculatedStructure: CalculatedStructure
    
    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case templateId = "template_id"
        case scheduledDate = "scheduled_date"
        case workoutType = "workout_type"
        case priorityLevel = "priority_level"
        case status
        case isCalibrationTest = "is_calibration_test"
        case calculatedStructure = "calculated_structure"
    }
}

struct CalculatedStructure: Codable {
    let title: String
    let description: String
    let totalDuration: Int
    let steps: [WorkoutStepResponse]
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case totalDuration = "total_duration"
        case steps
    }
}

struct WorkoutStepResponse: Codable {
    let type: String
    let duration: Int
    let targetZone: Int?
    let targetPace: String?
    let targetPower: Int?
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case duration
        case targetZone = "target_zone"
        case targetPace = "target_pace"
        case targetPower = "target_power"
        case description
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError
    case unknown(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized. Please sign in again."
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error. Please try again later."
        case .unknown(let code):
            return "Unknown error (code: \(code))"
        }
    }
}

// MARK: - Additional Response Models

struct UserResponse: Codable {
    let id: String
    let email: String
    let authId: String
    let subscriptionStatus: String
    let experienceLevel: String?
    let unitPreference: String
    let isPrivate: Bool
    let displayName: String?
    let avatarUrl: String?
    let trialEndsAt: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case authId = "auth_id"
        case subscriptionStatus = "subscription_status"
        case experienceLevel = "experience_level"
        case unitPreference = "unit_preference"
        case isPrivate = "is_private"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case trialEndsAt = "trial_ends_at"
        case createdAt = "created_at"
    }
}

struct OnboardingResponse: Codable {
    let user: UserResponse
    let plan: PlanResponse
}

struct PlanResponse: Codable {
    let id: String
    let userId: String
    let name: String
    let raceDate: String
    let startDate: String
    let raceDistanceType: String
    let status: String
    let raceId: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, status
        case userId = "user_id"
        case raceDate = "race_date"
        case startDate = "start_date"
        case raceDistanceType = "race_distance_type"
        case raceId = "race_id"
        case createdAt = "created_at"
    }
}

struct BiometricsResponse: Codable {
    let id: String
    let userId: String
    let recordedAt: String
    let cssPacePer100: Int?
    let runThresholdPacePerMile: Int?
    let bikeFtp: Int?
    let maxHeartRate: Int?
    let restingHeartRate: Int?
    let calibrationSource: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case recordedAt = "recorded_at"
        case cssPacePer100 = "css_pace_per_100"
        case runThresholdPacePerMile = "run_threshold_pace_per_mile"
        case bikeFtp = "bike_ftp"
        case maxHeartRate = "max_heart_rate"
        case restingHeartRate = "resting_heart_rate"
        case calibrationSource = "calibration_source"
    }
}

struct RaceResponse: Codable {
    let id: String
    let name: String
    let date: String
    let location: String
    let distanceType: String
    let swimDistanceMeters: Int
    let bikeDistanceMeters: Int
    let runDistanceMeters: Int
    let websiteUrl: String?
    let isCustom: Bool
    let userId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, date, location
        case distanceType = "distance_type"
        case swimDistanceMeters = "swim_distance_meters"
        case bikeDistanceMeters = "bike_distance_meters"
        case runDistanceMeters = "run_distance_meters"
        case websiteUrl = "website_url"
        case isCustom = "is_custom"
        case userId = "user_id"
    }
}

struct SocialFeedResponse: Codable {
    let activities: [SocialActivityResponse]
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case activities
        case hasMore = "has_more"
    }
}

struct SocialActivityResponse: Codable {
    let id: String
    let workoutId: String?
    let userId: String
    let completedAt: String
    let totalDurationSeconds: Int
    let totalDistanceMeters: Int?
    let avgHeartRate: Int?
    let source: String
    let user: SocialUserResponse?
    let kudosCount: Int
    let hasKudos: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case workoutId = "workout_id"
        case userId = "user_id"
        case completedAt = "completed_at"
        case totalDurationSeconds = "total_duration_seconds"
        case totalDistanceMeters = "total_distance_meters"
        case avgHeartRate = "avg_heart_rate"
        case source, user
        case kudosCount = "kudos_count"
        case hasKudos = "has_kudos"
    }
}

struct SocialUserResponse: Codable {
    let id: String
    let email: String
    let displayName: String?
    let avatarUrl: String?
    let isPrivate: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case isPrivate = "is_private"
    }
}

struct FriendResponse: Codable {
    let id: String
    let email: String
    let displayName: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}

