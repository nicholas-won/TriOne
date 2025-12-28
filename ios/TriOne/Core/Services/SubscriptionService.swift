import Foundation
import RevenueCat

/// Subscription service that handles all in-app purchases via RevenueCat
@MainActor
class SubscriptionService: NSObject, ObservableObject {
    static let shared = SubscriptionService()
    
    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Subscription State
    
    var isSubscribed: Bool {
        guard let customerInfo = customerInfo else { return false }
        return customerInfo.entitlements["premium"]?.isActive == true
    }
    
    var isTrialActive: Bool {
        guard let customerInfo = customerInfo else {
            // Fall back to local check if no RevenueCat info
            return AuthService.shared.currentUser?.isTrialActive == true
        }
        // Check if the user is on a trial period via RevenueCat
        if let premium = customerInfo.entitlements["premium"],
           premium.isActive,
           premium.periodType == .trial {
            return true
        }
        // Fall back to local trial check
        return AuthService.shared.currentUser?.isTrialActive == true
    }
    
    var hasAccess: Bool {
        isSubscribed || isTrialActive
    }
    
    var trialDaysRemaining: Int {
        guard let user = AuthService.shared.currentUser,
              let trialEndsAt = user.trialEndsAt else {
            return 0
        }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: trialEndsAt).day ?? 0
        return max(0, days)
    }
    
    // MARK: - Products
    
    var monthlyPackage: Package? {
        offerings?.current?.monthly
    }
    
    var annualPackage: Package? {
        offerings?.current?.annual
    }
    
    var monthlyPrice: String {
        monthlyPackage?.storeProduct.localizedPriceString ?? "$9.99/month"
    }
    
    var annualPrice: String {
        annualPackage?.storeProduct.localizedPriceString ?? "$79.99/year"
    }
    
    var annualMonthlySavings: String {
        guard let monthly = monthlyPackage?.storeProduct.price as? NSDecimalNumber,
              let annual = annualPackage?.storeProduct.price as? NSDecimalNumber else {
            return "Save 33%"
        }
        let monthlyAnnualized = monthly.doubleValue * 12
        let savings = ((monthlyAnnualized - annual.doubleValue) / monthlyAnnualized) * 100
        return "Save \(Int(savings))%"
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        configureRevenueCat()
    }
    
    private func configureRevenueCat() {
        guard !Config.revenueCatAPIKey.isEmpty else {
            print("⚠️ RevenueCat API key not configured. Subscriptions will use mock data.")
            return
        }
        
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Config.revenueCatAPIKey)
        
        // Listen for customer info updates
        Purchases.shared.delegate = self
        
        Task {
            await fetchOfferings()
            await refreshCustomerInfo()
        }
    }
    
    // MARK: - Fetch Data
    
    func fetchOfferings() async {
        isLoading = true
        defer { isLoading = false }
        
        guard !Config.revenueCatAPIKey.isEmpty else {
            // Use mock offerings in dev mode
            return
        }
        
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            // Handle App Store Connect errors gracefully (app not found, etc.)
            if let nsError = error as NSError?,
               let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
               underlyingError.domain == "AMSErrorDomain" {
                print("⚠️ App Store Connect error (app may not be registered yet): \(underlyingError.localizedDescription)")
                print("💡 This is normal if the app hasn't been created in App Store Connect yet.")
                // Don't set errorMessage for expected App Store Connect errors
                return
            }
            print("Failed to fetch offerings: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func refreshCustomerInfo() async {
        guard !Config.revenueCatAPIKey.isEmpty else { return }
        
        do {
            customerInfo = try await Purchases.shared.customerInfo()
        } catch {
            // Handle App Store Connect errors gracefully
            if let nsError = error as NSError?,
               let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
               underlyingError.domain == "AMSErrorDomain" {
                print("⚠️ App Store Connect error (app may not be registered yet): \(underlyingError.localizedDescription)")
                return
            }
            print("Failed to fetch customer info: \(error)")
        }
    }
    
    // MARK: - Purchase
    
    func purchase(package: Package) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            // Check if the purchase was successful
            if result.customerInfo.entitlements["premium"]?.isActive == true {
                customerInfo = result.customerInfo
                
                // Update local user state
                AuthService.shared.updateUser { user in
                    user.subscriptionStatus = .active
                    user.trialEndsAt = nil // No longer on trial
                }
            }
        } catch {
            // Handle App Store Connect errors gracefully
            if let nsError = error as NSError?,
               let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
               underlyingError.domain == "AMSErrorDomain" {
                print("⚠️ App Store Connect error (app may not be registered yet): \(underlyingError.localizedDescription)")
                throw SubscriptionError.purchaseFailed("App not registered in App Store Connect. Please complete App Store Connect setup first.")
            }
            throw error
        }
    }
    
    func purchaseMonthly() async throws {
        guard let package = monthlyPackage else {
            throw SubscriptionError.noOfferings
        }
        try await purchase(package: package)
    }
    
    func purchaseAnnual() async throws {
        guard let package = annualPackage else {
            throw SubscriptionError.noOfferings
        }
        try await purchase(package: package)
    }
    
    // MARK: - Restore
    
    func restorePurchases() async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard !Config.revenueCatAPIKey.isEmpty else {
            throw SubscriptionError.notConfigured
        }
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            
            // Check if restoration found an active subscription
            if customerInfo.entitlements["premium"]?.isActive == true {
                AuthService.shared.updateUser { user in
                    user.subscriptionStatus = .active
                }
            }
        } catch {
            // Handle App Store Connect errors gracefully
            if let nsError = error as NSError?,
               let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
               underlyingError.domain == "AMSErrorDomain" {
                print("⚠️ App Store Connect error (app may not be registered yet): \(underlyingError.localizedDescription)")
                print("💡 This is normal if the app hasn't been created in App Store Connect yet.")
                throw SubscriptionError.purchaseFailed("App not registered in App Store Connect. Please complete App Store Connect setup first.")
            }
            throw error
        }
    }
    
    // MARK: - Trial
    
    func activateTrial() {
        AuthService.shared.activateTrial()
    }
    
    // MARK: - Identify User
    
    func identifyUser(_ userId: String) async {
        guard !Config.revenueCatAPIKey.isEmpty else { return }
        
        do {
            let (customerInfo, _) = try await Purchases.shared.logIn(userId)
            self.customerInfo = customerInfo
        } catch {
            // Handle App Store Connect errors gracefully
            if let nsError = error as NSError?,
               let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
               underlyingError.domain == "AMSErrorDomain" {
                print("⚠️ App Store Connect error (app may not be registered yet): \(underlyingError.localizedDescription)")
                return
            }
            print("Failed to identify user: \(error)")
        }
    }
    
    func logout() async {
        guard !Config.revenueCatAPIKey.isEmpty else { return }
        
        do {
            customerInfo = try await Purchases.shared.logOut()
        } catch {
            print("Failed to logout: \(error)")
        }
    }
}

// MARK: - PurchasesDelegate
extension SubscriptionService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
        }
    }
}

// MARK: - Errors
enum SubscriptionError: LocalizedError {
    case noOfferings
    case notConfigured
    case purchaseFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noOfferings:
            return "No subscription packages available"
        case .notConfigured:
            return "Subscription service is not configured"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        }
    }
}

