import SwiftUI

struct OnboardingFlow: View {
    @StateObject private var viewModel = OnboardingViewModel()
    
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            GoalSelectionView()
                .environmentObject(viewModel)
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .goal:
                        GoalSelectionView()
                    case .race:
                        RaceSelectionView()
                    case .experience:
                        ExperienceView()
                    case .calibration:
                        CalibrationView()
                    case .hardware:
                        HardwareView()
                    }
                }
        }
        .environmentObject(viewModel)
    }
}

enum OnboardingStep: Hashable {
    case goal
    case race
    case experience
    case calibration
    case hardware
}

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var goalDistance: Constants.RaceDistance?
    @Published var selectedRaceId: String?
    @Published var experienceLevel: ExperienceLevel?
    @Published var swimPace: Int?
    @Published var bikePower: Int?
    @Published var runPace: Int?
    @Published var hasHeartRateMonitor = false
    @Published var unitPreference: UnitPreference = .imperial
    
    var needsCalibration: Bool {
        swimPace == nil || bikePower == nil || runPace == nil
    }
    
    func navigateTo(_ step: OnboardingStep) {
        navigationPath.append(step)
    }
    
    func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
    
    func completeOnboarding() {
        let authService = AuthService.shared
        
        authService.updateUser { user in
            user.experienceLevel = self.experienceLevel
            user.goalDistance = self.goalDistance
            user.hasHeartRateMonitor = self.hasHeartRateMonitor
            user.unitPreference = self.unitPreference
            
            // Initialize biometrics if nil
            if user.biometrics == nil {
                user.biometrics = Biometrics(userId: user.id)
            }
            
            // Update biometrics with calibration values
            if let swimPace = self.swimPace {
                user.biometrics?.criticalSwimSpeed = Double(swimPace)
            }
            if let bikePower = self.bikePower {
                user.biometrics?.functionalThresholdPower = bikePower
            }
            if let runPace = self.runPace {
                user.biometrics?.thresholdRunPace = runPace
            }
            user.biometrics?.recordedAt = Date()
        }
    }
}

// MARK: - Progress Indicator
struct OnboardingProgress: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index < currentStep ? Theme.primary : Theme.border)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

#Preview {
    OnboardingFlow()
        .environmentObject(AppState())
        .environmentObject(AuthService.shared)
}

