import SwiftUI

struct UnitsSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedUnit: UnitPreference = .imperial
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Description
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Theme.primary)
                    
                    Text("Choose your preferred unit system. This affects how distances, paces, and temperatures are displayed throughout the app.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(16)
                .background(Theme.primary.opacity(0.05))
                .cornerRadius(12)
                
                // Unit Options
                ForEach(UnitPreference.allCases, id: \.self) { unit in
                    UnitOptionCard(
                        preference: unit,
                        isSelected: selectedUnit == unit
                    ) {
                        HapticService.shared.selection()
                        selectedUnit = unit
                        authService.updateUnitPreference(unit)
                    }
                }
            }
            .padding(24)
        }
        .background(Theme.backgroundSecondary)
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedUnit = authService.currentUser?.unitPreference ?? .imperial
        }
    }
}

struct UnitOptionCard: View {
    let preference: UnitPreference
    let isSelected: Bool
    let action: () -> Void
    
    var examples: [(String, String)] {
        switch preference {
        case .imperial:
            return [
                ("Distance", "5.0 miles"),
                ("Pace", "8:00 min/mi"),
                ("Pool Length", "25 yards"),
                ("Temperature", "72°F")
            ]
        case .metric:
            return [
                ("Distance", "8.0 km"),
                ("Pace", "5:00 min/km"),
                ("Pool Length", "25 meters"),
                ("Temperature", "22°C")
            ]
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preference.displayName)
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        
                        Text(preference.description)
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
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(examples, id: \.0) { example in
                        HStack {
                            Text(example.0)
                                .font(.caption)
                                .foregroundStyle(Theme.textMuted)
                            
                            Spacer()
                            
                            Text(example.1)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.text)
                        }
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
        UnitsSettingsView()
            .environmentObject(AuthService.shared)
    }
}

