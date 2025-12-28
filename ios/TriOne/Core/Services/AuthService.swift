import SwiftUI
import Combine
import Auth

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var isDevMode = false
    @Published var authError: String?
    
    private let userDefaultsKey = "devModeUser"
    private let supabase = SupabaseService.shared
    
    private init() {
        loadPersistedState()
    }
    
    // MARK: - Initialization
    
    private func loadPersistedState() {
        isDevMode = UserDefaults.standard.bool(forKey: "isDevMode")
        
        if isDevMode {
            // Load dev mode user from UserDefaults
            if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
               let user = try? JSONDecoder().decode(User.self, from: data) {
                currentUser = user
                isAuthenticated = true
            } else {
                currentUser = User.devUser
                isAuthenticated = true
            }
            isLoading = false
        } else {
            // Wait for Supabase to initialize
            Task {
                await waitForSupabaseInit()
            }
        }
    }
    
    private func waitForSupabaseInit() async {
        // Wait for Supabase to check existing session
        while !supabase.isInitialized {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if let session = supabase.session {
            await handleSessionChange(session: session)
        }
        
        isLoading = false
    }
    
    // MARK: - Session Handling
    
    func handleSessionChange(session: Session) async {
        // Fetch or create user profile from our backend
        do {
            let userProfile = try await fetchOrCreateUserProfile(
                authId: session.user.id.uuidString,
                email: session.user.email ?? ""
            )
            currentUser = userProfile
            isAuthenticated = true
            isDevMode = false
            
            // Update API service with token
            APIService.shared.setAuthToken(session.accessToken)
        } catch {
            print("Failed to fetch user profile: \(error)")
            authError = error.localizedDescription
        }
    }
    
    func handleSignOut() {
        currentUser = nil
        isAuthenticated = false
        isDevMode = false
        APIService.shared.setAuthToken(nil)
        
        // Clear app state
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "hasActiveTrial")
        WorkoutService.shared.clearAllData()
    }
    
    // MARK: - Auth Actions
    
    func signUp(email: String, password: String) async throws {
        isLoading = true
        authError = nil
        
        defer { isLoading = false }
        
        do {
            let session = try await supabase.signUp(email: email, password: password)
            await handleSessionChange(session: session)
        } catch {
            authError = error.localizedDescription
            throw AuthError.signUpFailed(error.localizedDescription)
        }
    }
    
    func signIn(email: String, password: String) async throws {
        isLoading = true
        authError = nil
        
        defer { isLoading = false }
        
        do {
            let session = try await supabase.signIn(email: email, password: password)
            await handleSessionChange(session: session)
        } catch {
            authError = error.localizedDescription
            throw AuthError.signInFailed(error.localizedDescription)
        }
    }
    
    func signInWithApple(idToken: String, nonce: String) async throws {
        isLoading = true
        authError = nil
        
        defer { isLoading = false }
        
        do {
            let session = try await supabase.signInWithApple(idToken: idToken, nonce: nonce)
            await handleSessionChange(session: session)
        } catch {
            authError = error.localizedDescription
            throw AuthError.socialAuthFailed(error.localizedDescription)
        }
    }
    
    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        isLoading = true
        authError = nil
        
        defer { isLoading = false }
        
        do {
            let session = try await supabase.signInWithGoogle(idToken: idToken, accessToken: accessToken)
            await handleSessionChange(session: session)
        } catch {
            authError = error.localizedDescription
            throw AuthError.socialAuthFailed(error.localizedDescription)
        }
    }
    
    func signOut() {
        Task {
            if !isDevMode {
                try? await supabase.signOut()
            }
            handleSignOut()
            
            if isDevMode {
                disableDevMode()
            }
        }
    }
    
    func resetPassword(email: String) async throws {
        do {
            try await supabase.resetPassword(email: email)
        } catch {
            throw AuthError.resetPasswordFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Dev Mode
    
    func enableDevMode() {
        isDevMode = true
        currentUser = User.devUser
        isAuthenticated = true
        UserDefaults.standard.set(true, forKey: "isDevMode")
        persistUser()
    }
    
    func disableDevMode() {
        isDevMode = false
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.set(false, forKey: "isDevMode")
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    // MARK: - User Updates
    
    func updateUser(_ updates: (inout User) -> Void) {
        guard var user = currentUser else { return }
        updates(&user)
        user.updatedAt = Date()
        currentUser = user
        
        if isDevMode {
            persistUser()
        } else {
            // Sync to backend
            Task {
                await syncUserToBackend(user)
            }
        }
    }
    
    func updateBiometrics(
        criticalSwimSpeed: Double? = nil,
        functionalThresholdPower: Int? = nil,
        thresholdRunPace: Int? = nil
    ) {
        updateUser { user in
            // Initialize biometrics if nil
            if user.biometrics == nil {
                user.biometrics = Biometrics(userId: user.id)
            }
            
            // Update individual fields if provided
            if let css = criticalSwimSpeed {
                user.biometrics?.criticalSwimSpeed = css
            }
            if let ftp = functionalThresholdPower {
                user.biometrics?.functionalThresholdPower = ftp
            }
            if let pace = thresholdRunPace {
                user.biometrics?.thresholdRunPace = pace
            }
            user.biometrics?.recordedAt = Date()
        }
    }
    
    func updateUnitPreference(_ preference: UnitPreference) {
        updateUser { user in
            user.unitPreference = preference
        }
    }
    
    func completeOnboarding(experienceLevel: ExperienceLevel, goalDistance: Constants.RaceDistance?) {
        updateUser { user in
            user.experienceLevel = experienceLevel
            user.goalDistance = goalDistance
        }
    }
    
    func activateTrial() {
        updateUser { user in
            user.subscriptionStatus = .trial
            user.trialEndsAt = Calendar.current.date(byAdding: .day, value: Constants.trialDurationDays, to: Date())
        }
    }
    
    // MARK: - Backend Sync
    
    private func fetchOrCreateUserProfile(authId: String, email: String) async throws -> User {
        // Call our backend API to get/create user
        let data = try await APIService.shared.getUserProfile()
        return try JSONDecoder().decode(User.self, from: data)
    }
    
    private func syncUserToBackend(_ user: User) async {
        do {
            try await APIService.shared.updateUserProfile(user: user)
        } catch {
            print("Failed to sync user to backend: \(error)")
        }
    }
    
    // MARK: - Persistence (Dev Mode)
    
    private func persistUser() {
        guard isDevMode, let user = currentUser else {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            return
        }
        
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    // MARK: - Legacy Social Auth (Temporary - for transition)
    
    func signInWithAppleLegacy(userID: String, email: String?, firstName: String?, lastName: String?) {
        let displayName = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        
        let user = User(
            id: userID,
            email: email ?? "apple-user@trione.app",
            firstName: firstName,
            lastName: lastName,
            displayName: displayName.isEmpty ? nil : displayName,
            avatarUrl: nil,
            subscriptionStatus: .trial,
            trialEndsAt: Calendar.current.date(byAdding: .day, value: Constants.trialDurationDays, to: Date()),
            unitPreference: .imperial,
            isPrivate: false,
            onboardingStatus: .started,
            trainingVolumeTier: 1,
            calibrationMethod: .manualInput,
            dateOfBirth: nil,
            gender: nil,
            primaryRaceId: nil,
            biometrics: nil,
            experienceLevel: nil,
            goalDistance: nil,
            hasHeartRateMonitor: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        currentUser = user
        isAuthenticated = true
        isDevMode = true
        UserDefaults.standard.set(true, forKey: "isDevMode")
        persistUser()
    }
    
    func signInWithGoogleLegacy(userID: String, email: String?, displayName: String?) {
        let user = User(
            id: userID,
            email: email ?? "google-user@trione.app",
            firstName: nil,
            lastName: nil,
            displayName: displayName,
            avatarUrl: nil,
            subscriptionStatus: .trial,
            trialEndsAt: Calendar.current.date(byAdding: .day, value: Constants.trialDurationDays, to: Date()),
            unitPreference: .imperial,
            isPrivate: false,
            onboardingStatus: .started,
            trainingVolumeTier: 1,
            calibrationMethod: .manualInput,
            dateOfBirth: nil,
            gender: nil,
            primaryRaceId: nil,
            biometrics: nil,
            experienceLevel: nil,
            goalDistance: nil,
            hasHeartRateMonitor: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        currentUser = user
        isAuthenticated = true
        isDevMode = true
        UserDefaults.standard.set(true, forKey: "isDevMode")
        persistUser()
    }
}

enum AuthError: LocalizedError {
    case notImplemented
    case invalidCredentials
    case networkError
    case signUpFailed(String)
    case signInFailed(String)
    case socialAuthFailed(String)
    case resetPasswordFailed(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notImplemented: return "This feature is not yet implemented"
        case .invalidCredentials: return "Invalid email or password"
        case .networkError: return "Network error. Please try again."
        case .signUpFailed(let message): return "Sign up failed: \(message)"
        case .signInFailed(let message): return "Sign in failed: \(message)"
        case .socialAuthFailed(let message): return "Social login failed: \(message)"
        case .resetPasswordFailed(let message): return "Password reset failed: \(message)"
        case .unknown: return "An unknown error occurred"
        }
    }
}
