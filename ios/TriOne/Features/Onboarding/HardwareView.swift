import SwiftUI

struct HardwareView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(currentStep: 5, totalSteps: 5)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Back Button
                    Button {
                        viewModel.goBack()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.text)
                            .frame(width: 40, height: 40)
                            .background(Theme.backgroundSecondary)
                            .clipShape(Circle())
                    }
                    .padding(.top, 16)
                    
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Final setup")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.text)
                        
                        Text("A few more preferences to personalize your experience")
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                    
                    // Heart Rate Monitor
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Do you train with a heart rate monitor?")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        
                        HStack(spacing: 12) {
                            ToggleCard(
                                icon: "heart.fill",
                                title: "Yes",
                                isSelected: viewModel.hasHeartRateMonitor
                            ) {
                                HapticService.shared.selection()
                                viewModel.hasHeartRateMonitor = true
                            }
                            
                            ToggleCard(
                                icon: "heart.slash.fill",
                                title: "No",
                                isSelected: !viewModel.hasHeartRateMonitor
                            ) {
                                HapticService.shared.selection()
                                viewModel.hasHeartRateMonitor = false
                            }
                        }
                    }
                    .padding(.bottom, 24)
                    
                    // Unit Preference
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preferred units")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        
                        HStack(spacing: 12) {
                            UnitCard(
                                preference: .imperial,
                                isSelected: viewModel.unitPreference == .imperial
                            ) {
                                HapticService.shared.selection()
                                viewModel.unitPreference = .imperial
                            }
                            
                            UnitCard(
                                preference: .metric,
                                isSelected: viewModel.unitPreference == .metric
                            ) {
                                HapticService.shared.selection()
                                viewModel.unitPreference = .metric
                            }
                        }
                    }
                    .padding(.bottom, 24)
                    
                    // Health Data Info
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.primary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Health Data Access")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.text)
                            
                            Text("We'll ask for permission to read your health data to automatically track your workouts and provide better insights.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(16)
                    .background(Theme.backgroundSecondary)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
            }
            
            // Complete Button
            VStack(spacing: 0) {
                Divider()
                
                Button {
                    completeSetup()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Complete Setup")
                            .primaryButtonStyle()
                    }
                }
                .disabled(isLoading)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color.white)
        }
        .background(Color.white)
        .navigationBarBackButtonHidden()
    }
    
    private func completeSetup() {
        isLoading = true
        
        viewModel.completeOnboarding()
        appState.completeOnboarding()
        
        HapticService.shared.success()
        isLoading = false
    }
}

struct ToggleCard: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Theme.primary : Theme.textMuted)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Theme.primary : Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Theme.primary.opacity(0.05) : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Theme.primary : Theme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct UnitCard: View {
    let preference: UnitPreference
    let isSelected: Bool
    let action: () -> Void
    
    var emoji: String {
        preference == .imperial ? "🇺🇸" : "🌍"
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.title)
                
                Text(preference.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Theme.primary : Theme.textSecondary)
                
                Text(preference.description)
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Theme.primary.opacity(0.05) : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Theme.primary : Theme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        HardwareView()
            .environmentObject(OnboardingViewModel())
            .environmentObject(AppState())
    }
}

