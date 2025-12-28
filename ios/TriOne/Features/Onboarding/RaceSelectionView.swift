import SwiftUI

struct RaceSelectionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var searchText = ""
    @State private var races: [Race] = Race.mockRaces
    
    var filteredRaces: [Race] {
        if searchText.isEmpty {
            return races.filter { $0.distanceType == viewModel.goalDistance }
        }
        return races.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.location.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(currentStep: 2, totalSteps: 5)
            
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
                        Text("Pick your race")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.text)
                        
                        Text("Select an official race or create your own")
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                    
                    // Search
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.textMuted)
                        
                        TextField("Search races...", text: $searchText)
                    }
                    .padding(16)
                    .background(Theme.backgroundSecondary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .padding(.bottom, 16)
                    
                    // Skip / Custom Race
                    Button {
                        viewModel.selectedRaceId = nil
                        viewModel.navigateTo(.experience)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.primary.opacity(0.1))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "plus")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Theme.primary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Skip for now")
                                    .font(.headline)
                                    .foregroundStyle(Theme.primary)
                                
                                Text("I'll add a race later")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textMuted)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Theme.textMuted)
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                .foregroundColor(Theme.primary)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)
                    
                    // Race List
                    Text("Popular Races")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textMuted)
                        .textCase(.uppercase)
                        .padding(.bottom, 12)
                    
                    ForEach(filteredRaces) { race in
                        RaceSelectionCard(
                            race: race,
                            isSelected: viewModel.selectedRaceId == race.id
                        ) {
                            HapticService.shared.selection()
                            viewModel.selectedRaceId = race.id
                        }
                        .padding(.bottom, 12)
                    }
                }
                .padding(.horizontal, 24)
            }
            
            // Continue Button
            VStack(spacing: 0) {
                Divider()
                
                Button {
                    viewModel.navigateTo(.experience)
                } label: {
                    Text("Continue")
                        .primaryButtonStyle()
                }
                .disabled(viewModel.selectedRaceId == nil)
                .opacity(viewModel.selectedRaceId == nil ? 0.5 : 1)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color.white)
        }
        .background(Color.white)
        .navigationBarBackButtonHidden()
    }
}

struct RaceSelectionCard: View {
    let race: Race
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(race.name)
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        
                        Text(race.location)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        
                        Text(race.formattedDate)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("\(race.daysUntil)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.text)
                        
                        Text("days")
                            .font(.caption)
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                
                Divider()
                
                HStack {
                    Label("\(String(format: "%.1f", race.swimKm))km", systemImage: "drop.fill")
                        .foregroundStyle(Theme.swim)
                    
                    Spacer()
                    
                    Label("\(Int(race.bikeKm))km", systemImage: "bicycle")
                        .foregroundStyle(Theme.bike)
                    
                    Spacer()
                    
                    Label("\(String(format: "%.1f", race.runKm))km", systemImage: "figure.run")
                        .foregroundStyle(Theme.run)
                }
                .font(.caption)
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
        RaceSelectionView()
            .environmentObject(OnboardingViewModel())
    }
}

