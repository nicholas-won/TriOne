import SwiftUI

struct GoalSelectionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(currentStep: 1, totalSteps: 5)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What's your goal?")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.text)
                        
                        Text("Select the race distance you're training for")
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 32)
                    
                    // Options
                    VStack(spacing: 12) {
                        ForEach(Constants.RaceDistance.allCases, id: \.self) { distance in
                            DistanceCard(
                                distance: distance,
                                isSelected: viewModel.goalDistance == distance
                            ) {
                                HapticService.shared.selection()
                                viewModel.goalDistance = distance
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            
            // Continue Button
            VStack(spacing: 0) {
                Divider()
                
                Button {
                    viewModel.navigateTo(.race)
                } label: {
                    Text("Continue")
                        .primaryButtonStyle()
                }
                .disabled(viewModel.goalDistance == nil)
                .opacity(viewModel.goalDistance == nil ? 0.5 : 1)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color.white)
        }
        .background(Color.white)
        .navigationBarBackButtonHidden()
    }
}

struct DistanceCard: View {
    let distance: Constants.RaceDistance
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(distance.displayName)
                        .font(.headline)
                        .foregroundStyle(isSelected ? Theme.primary : Theme.text)
                    
                    HStack(spacing: 12) {
                        Label("\(String(format: "%.1f", Double(distance.distances.swim) / 1000))km", systemImage: "drop.fill")
                            .foregroundStyle(Theme.swim)
                        Label("\(distance.distances.bike / 1000)km", systemImage: "bicycle")
                            .foregroundStyle(Theme.bike)
                        Label("\(String(format: "%.1f", Double(distance.distances.run) / 1000))km", systemImage: "figure.run")
                            .foregroundStyle(Theme.run)
                    }
                    .font(.caption)
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

#Preview {
    NavigationStack {
        GoalSelectionView()
            .environmentObject(OnboardingViewModel())
    }
}

