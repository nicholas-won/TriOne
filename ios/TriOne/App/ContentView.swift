import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @State private var showTrialExpiredAlert = false
    
    var body: some View {
        Group {
            if authService.isLoading {
                LaunchScreen()
            } else if authService.isAuthenticated || authService.isDevMode {
                if !appState.hasCompletedOnboarding {
                    OnboardingFlow()
                } else if !appState.hasActiveTrial || appState.trialExpired {
                    // Show paywall when trial expires or no active subscription
                    PaywallView()
                        .overlay(
                            // Show banner for expired trials
                            trialExpiredBanner
                        )
                } else {
                    MainTabView()
                }
            } else {
                WelcomeView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: appState.hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.3), value: appState.hasActiveTrial)
        .onReceive(NotificationCenter.default.publisher(for: .trialExpired)) { _ in
            showTrialExpiredAlert = true
        }
        .alert("Trial Expired", isPresented: $showTrialExpiredAlert) {
            Button("Subscribe Now") {
                // Will automatically show paywall
            }
        } message: {
            Text("Your 14-day free trial has ended. Subscribe to continue using TriOne and keep training!")
        }
    }
    
    @ViewBuilder
    private var trialExpiredBanner: some View {
        if appState.trialExpired {
            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.warning)
                    
                    Text("Your trial has expired")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.text)
                    
                    Spacer()
                }
                .padding(12)
                .background(Theme.warning.opacity(0.15))
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                Spacer()
            }
        }
    }
    
}

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Theme.primary)
                
                Text("TriOne")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.text)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(AuthService.shared)
}

