import SwiftUI

struct ExperienceView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(currentStep: 3, totalSteps: 5)
            
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
                        Text("What's your focus?")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.text)
                        
                        Text("This helps us tailor your training intensity")
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                    
                    // Options
                    VStack(spacing: 16) {
                        ExperienceCard(
                            level: .finisher,
                            icon: "flag.checkered",
                            isSelected: viewModel.experienceLevel == .finisher
                        ) {
                            HapticService.shared.selection()
                            viewModel.experienceLevel = .finisher
                        }
                        
                        ExperienceCard(
                            level: .competitor,
                            icon: "trophy",
                            isSelected: viewModel.experienceLevel == .competitor
                        ) {
                            HapticService.shared.selection()
                            viewModel.experienceLevel = .competitor
                        }
                    }
                    
                    // Info
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Theme.primary)
                        
                        Text("You can change this anytime. Both approaches build fitness progressively—competitors just push harder during key workouts.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(16)
                    .background(Theme.primary.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.top, 24)
                }
                .padding(.horizontal, 24)
            }
            
            // Continue Button
            VStack(spacing: 0) {
                Divider()
                
                Button {
                    viewModel.navigateTo(.calibration)
                } label: {
                    Text("Continue")
                        .primaryButtonStyle()
                }
                .disabled(viewModel.experienceLevel == nil)
                .opacity(viewModel.experienceLevel == nil ? 0.5 : 1)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color.white)
        }
        .background(Color.white)
        .navigationBarBackButtonHidden()
    }
}

struct ExperienceCard: View {
    let level: ExperienceLevel
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.primary : Theme.backgroundSecondary)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : Theme.textMuted)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    
                    Text(level.description)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.primary : Theme.border, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Theme.primary)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .padding(20)
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

#Preview {
    NavigationStack {
        ExperienceView()
            .environmentObject(OnboardingViewModel())
    }
}

