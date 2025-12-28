import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool = false
    @Published var hasActiveTrial: Bool = false
    @Published var currentUser: User?
    @Published var trialExpired: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var trialCheckTimer: Timer?
    
    init() {
        // Load persisted state
        loadPersistedState()
        
        // Listen to auth changes
        AuthService.shared.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                self?.updateFromUser(user)
            }
            .store(in: &cancellables)
        
        // Set up periodic trial check
        startTrialExpirationCheck()
    }
    
    deinit {
        trialCheckTimer?.invalidate()
    }
    
    private func loadPersistedState() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        hasActiveTrial = UserDefaults.standard.bool(forKey: "hasActiveTrial")
    }
    
    private func updateFromUser(_ user: User?) {
        guard let user = user else { return }
        
        hasCompletedOnboarding = user.experienceLevel != nil
        
        // Check actual trial/subscription status including expiration
        hasActiveTrial = user.hasAccess
        trialExpired = user.isTrialExpired
        
        // Persist
        UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(hasActiveTrial, forKey: "hasActiveTrial")
    }
    
    private func startTrialExpirationCheck() {
        // Check every hour for trial expiration
        trialCheckTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkTrialExpiration()
            }
        }
        
        // Also check immediately on app launch/foreground
        checkTrialExpiration()
        
        // Listen for app foreground events
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkTrialExpiration()
            }
        }
    }
    
    private func checkTrialExpiration() {
        guard let user = currentUser else { return }
        
        // Check if trial has expired
        if user.isTrialExpired && !trialExpired {
            trialExpired = true
            hasActiveTrial = false
            UserDefaults.standard.set(false, forKey: "hasActiveTrial")
            
            // Post notification for UI to respond
            NotificationCenter.default.post(name: .trialExpired, object: nil)
        }
        
        // Also check via RevenueCat if available
        let subscriptionService = SubscriptionService.shared
        if subscriptionService.isSubscribed {
            hasActiveTrial = true
            trialExpired = false
        } else if subscriptionService.isTrialActive {
            hasActiveTrial = true
            trialExpired = false
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    func activateTrial() {
        hasActiveTrial = true
        trialExpired = false
        UserDefaults.standard.set(true, forKey: "hasActiveTrial")
    }
    
    func reset() {
        hasCompletedOnboarding = false
        hasActiveTrial = false
        trialExpired = false
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "hasActiveTrial")
    }
}

extension Notification.Name {
    static let trialExpired = Notification.Name("trialExpired")
}

