import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var selectedPlan: SubscriptionPlan = .annual
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    enum SubscriptionPlan {
        case monthly, annual
    }
    
    let features = [
        ("calendar", "Personalized Training Plan", "Tailored to your race and fitness level"),
        ("waveform.path.ecg", "Adaptive Workouts", "Your plan adjusts when life happens"),
        ("stopwatch", "Visual Coaching", "Guided workouts with haptic cues"),
        ("chart.line.uptrend.xyaxis", "Progress Tracking", "See your improvements over time"),
        ("person.2", "Social Features", "Share your journey with friends"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    ZStack {
                        Theme.primary
                        
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 64, height: 64)
                                
                                Image(systemName: "figure.run.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white)
                            }
                            
                            Text("Unlock TriOne")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            Text("Start your \(Constants.trialDurationDays)-day free trial")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.top, 64)
                        .padding(.bottom, 48)
                    }
                    .clipShape(
                        RoundedCorner(radius: 32, corners: [.bottomLeft, .bottomRight])
                    )
                    
                    // Features
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Everything you need to reach the finish line")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                            .padding(.bottom, 16)
                        
                        ForEach(features, id: \.0) { feature in
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.primary.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: feature.0)
                                        .foregroundStyle(Theme.primary)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feature.1)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Theme.text)
                                    
                                    Text(feature.2)
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.success)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(24)
                    
                    // Pricing
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose your plan")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        
                        // Annual
                        PlanCard(
                            title: "Annual",
                            price: subscriptionService.annualPackage != nil 
                                ? subscriptionService.annualPrice 
                                : "$79.99/year",
                            subtitle: subscriptionService.annualPackage != nil 
                                ? "billed annually" 
                                : "billed annually",
                            badge: subscriptionService.annualMonthlySavings,
                            isSelected: selectedPlan == .annual
                        ) {
                            HapticService.shared.selection()
                            selectedPlan = .annual
                        }
                        
                        // Monthly
                        PlanCard(
                            title: "Monthly",
                            price: subscriptionService.monthlyPackage != nil 
                                ? subscriptionService.monthlyPrice 
                                : "$9.99/month",
                            subtitle: nil,
                            badge: nil,
                            isSelected: selectedPlan == .monthly
                        ) {
                            HapticService.shared.selection()
                            selectedPlan = .monthly
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    
                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Theme.error)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                    }
                }
            }
            
            // CTA
            VStack(spacing: 12) {
                Divider()
                
                Button {
                    startTrial()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Start \(Constants.trialDurationDays)-Day Free Trial")
                            .primaryButtonStyle()
                    }
                }
                .disabled(isLoading)
                
                Text("Cancel anytime. No commitment required.")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                
                // Restore Purchases
                Button("Restore Purchases") {
                    Task {
                        await restorePurchases()
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.primary)
                .padding(.top, 4)
                
                Button("Sign out") {
                    authService.signOut()
                    appState.reset()
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .background(Color.white)
        }
        .background(Color.white)
        .task {
            await subscriptionService.fetchOfferings()
        }
    }
    
    private func startTrial() {
        isLoading = true
        errorMessage = nil
        
        Task {
            // If RevenueCat is configured, try to start a trial via purchase
            if subscriptionService.monthlyPackage != nil || subscriptionService.annualPackage != nil {
                do {
                    if selectedPlan == .annual, let _ = subscriptionService.annualPackage {
                        try await subscriptionService.purchaseAnnual()
                    } else if let _ = subscriptionService.monthlyPackage {
                        try await subscriptionService.purchaseMonthly()
                    } else {
                        // Fall back to local trial
                        subscriptionService.activateTrial()
                    }
                    appState.activateTrial()
                    HapticService.shared.success()
                } catch {
                    // If purchase fails, still allow trial activation for development
                    print("Purchase error (activating local trial): \(error)")
                    subscriptionService.activateTrial()
                    appState.activateTrial()
                    HapticService.shared.success()
                }
            } else {
                // No RevenueCat offerings, use local trial
                subscriptionService.activateTrial()
                appState.activateTrial()
                HapticService.shared.success()
            }
            
            isLoading = false
        }
    }
    
    private func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await subscriptionService.restorePurchases()
            if subscriptionService.isSubscribed {
                appState.activateTrial() // This will give them access
                HapticService.shared.success()
            } else {
                errorMessage = "No active subscription found"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct PlanCard: View {
    let title: String
    let price: String
    let subtitle: String?
    let badge: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.success)
                                .cornerRadius(12)
                        }
                    }
                    
                    if let subtitle = subtitle {
                        Text("\(price), \(subtitle)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text(price)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.primary : Theme.border, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Theme.primary)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(16)
            .background(isSelected ? Theme.primary.opacity(0.05) : Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Theme.primary : Theme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    PaywallView()
        .environmentObject(AppState())
        .environmentObject(AuthService.shared)
}
