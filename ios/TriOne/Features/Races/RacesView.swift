import SwiftUI

struct RacesView: View {
    @EnvironmentObject var authService: AuthService
    @State private var races: [Race] = Race.mockRaces
    @State private var searchText = ""
    @State private var showAddRace = false
    @State private var isUpdatingRace = false
    
    var selectedRace: Race? {
        guard let primaryRaceId = authService.currentUser?.primaryRaceId else { return nil }
        return races.first { $0.id == primaryRaceId }
    }
    
    var upcomingRaces: [Race] {
        let filtered = filteredRaces.filter { race in
            race.id != selectedRace?.id
        }
        return filtered.sorted { $0.date < $1.date }
    }
    
    var filteredRaces: [Race] {
        if searchText.isEmpty {
            return races.filter { $0.date > Date() }
        }
        return races.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.location.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Races")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.text)
                        
                        Text("Manage your upcoming events")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Selected Race Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Next Race")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.textMuted)
                            .textCase(.uppercase)
                            .padding(.horizontal, 24)
                        
                        if let selectedRace = selectedRace {
                            SelectedRaceCard(race: selectedRace, isUpdating: isUpdatingRace) {
                                deselectRace()
                            }
                            .padding(.horizontal, 24)
                        } else {
                            NoRaceSelectedCard()
                                .padding(.horizontal, 24)
                        }
                    }
                    
                    // Search
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.textMuted)
                        
                        TextField("Search races...", text: $searchText)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    
                    // Add Race Button
                    Button {
                        showAddRace = true
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
                                Text("Add Custom Race")
                                    .font(.headline)
                                    .foregroundStyle(Theme.primary)
                                
                                Text("Enter your own race details")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textMuted)
                            }
                            
                            Spacer()
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
                    .padding(.horizontal, 24)
                    
                    // Race List
                    if !upcomingRaces.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Upcoming Races")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.textMuted)
                                .textCase(.uppercase)
                                .padding(.horizontal, 24)
                            
                            ForEach(upcomingRaces) { race in
                                RaceCard(race: race, isSelectable: true) {
                                    selectRace(race)
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                    
                    if upcomingRaces.isEmpty && searchText.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "flag")
                                .font(.system(size: 48))
                                .foregroundStyle(Theme.textMuted)
                            
                            Text("No races found")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Theme.backgroundSecondary)
            .sheet(isPresented: $showAddRace) {
                AddRaceSheet(races: $races)
            }
        }
    }
    
    private func selectRace(_ race: Race) {
        guard !isUpdatingRace else { return }
        isUpdatingRace = true
        
        Task {
            do {
                if !authService.isDevMode {
                    try await APIService.shared.updatePrimaryRace(raceId: race.id)
                }
                
                await MainActor.run {
                    authService.updateUser { user in
                        user.primaryRaceId = race.id
                    }
                    isUpdatingRace = false
                }
            } catch {
                print("Failed to update primary race: \(error)")
                await MainActor.run {
                    isUpdatingRace = false
                }
            }
        }
    }
    
    private func deselectRace() {
        guard !isUpdatingRace else { return }
        isUpdatingRace = true
        
        Task {
            do {
                if !authService.isDevMode {
                    try await APIService.shared.updatePrimaryRace(raceId: nil)
                }
                
                await MainActor.run {
                    authService.updateUser { user in
                        user.primaryRaceId = nil
                    }
                    isUpdatingRace = false
                }
            } catch {
                print("Failed to deselect race: \(error)")
                await MainActor.run {
                    isUpdatingRace = false
                }
            }
        }
    }
}

struct RaceCard: View {
    let race: Race
    var isSelectable: Bool = false
    var onSelect: (() -> Void)? = nil
    
    var body: some View {
        Button {
            onSelect?()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
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
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
    }
}

struct SelectedRaceCard: View {
    let race: Race
    let isUpdating: Bool
    let onDeselect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.success)
                            .font(.subheadline)
                        
                        Text(race.name)
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                    }
                    
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
            
            Button {
                onDeselect()
            } label: {
                HStack {
                    Spacer()
                    Text("Change Race")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.primary)
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(Theme.primary.opacity(0.1))
                .cornerRadius(8)
            }
            .disabled(isUpdating)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.success.opacity(0.3), lineWidth: 2)
        )
    }
}

struct NoRaceSelectedCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "flag.slash")
                    .font(.title2)
                    .foregroundStyle(Theme.textMuted)
                
                Text("No Race Currently Selected")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
            }
            
            Text("Select a race below to set it as your next race")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}

struct AddRaceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var races: [Race]
    
    @State private var name = ""
    @State private var location = ""
    @State private var date = Date()
    @State private var distanceType: Constants.RaceDistance = .olympic
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Race Name", text: $name)
                    TextField("Location", text: $location)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section("Distance") {
                    Picker("Distance Type", selection: $distanceType) {
                        ForEach(Constants.RaceDistance.allCases, id: \.self) { distance in
                            Text(distance.displayName).tag(distance)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Add Race")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addRace()
                    }
                    .disabled(name.isEmpty || location.isEmpty)
                }
            }
        }
    }
    
    private func addRace() {
        let distances = distanceType.distances
        let newRace = Race(
            id: UUID().uuidString,
            name: name,
            date: date,
            location: location,
            distanceType: distanceType,
            swimDistanceMeters: distances.swim,
            bikeDistanceMeters: distances.bike,
            runDistanceMeters: distances.run,
            websiteUrl: nil,
            isCustom: true,
            isOfficial: false
        )
        races.append(newRace)
        dismiss()
    }
}

#Preview {
    RacesView()
}

