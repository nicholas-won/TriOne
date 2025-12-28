import SwiftUI

struct RacesView: View {
    @State private var races: [Race] = Race.mockRaces
    @State private var searchText = ""
    @State private var showAddRace = false
    
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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upcoming Races")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.textMuted)
                            .textCase(.uppercase)
                            .padding(.horizontal, 24)
                        
                        ForEach(filteredRaces.sorted { $0.date < $1.date }) { race in
                            RaceCard(race: race)
                                .padding(.horizontal, 24)
                        }
                        
                        if filteredRaces.isEmpty {
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
                }
                .padding(.bottom, 32)
            }
            .background(Theme.backgroundSecondary)
            .sheet(isPresented: $showAddRace) {
                AddRaceSheet(races: $races)
            }
        }
    }
}

struct RaceCard: View {
    let race: Race
    
    var body: some View {
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

