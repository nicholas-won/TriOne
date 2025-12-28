import SwiftUI

struct HeartRateZonesView: View {
    @EnvironmentObject var authService: AuthService
    
    @State private var maxHR = ""
    @State private var restingHR = ""
    @State private var zones: [HRZone] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Info
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundStyle(Theme.error)
                    
                    Text("Heart rate zones help us calibrate workout intensity. Enter your max HR and resting HR to calculate your personal zones.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(16)
                .background(Theme.error.opacity(0.05))
                .cornerRadius(12)
                
                // Input Section
                VStack(spacing: 16) {
                    // Max HR
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Maximum Heart Rate")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.text)
                        
                        HStack {
                            TextField("185", text: $maxHR)
                                .keyboardType(.numberPad)
                                .textInputField()
                                .onChange(of: maxHR) { _, _ in
                                    calculateZones()
                                }
                            
                            Text("bpm")
                                .foregroundStyle(Theme.textMuted)
                        }
                        
                        Text("220 - age is a common estimate")
                            .font(.caption)
                            .foregroundStyle(Theme.textMuted)
                    }
                    
                    // Resting HR
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resting Heart Rate")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.text)
                        
                        HStack {
                            TextField("60", text: $restingHR)
                                .keyboardType(.numberPad)
                                .textInputField()
                                .onChange(of: restingHR) { _, _ in
                                    calculateZones()
                                }
                            
                            Text("bpm")
                                .foregroundStyle(Theme.textMuted)
                        }
                        
                        Text("Measure first thing in the morning")
                            .font(.caption)
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)
                
                // Zones Display
                if !zones.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Zones")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        
                        ForEach(zones) { zone in
                            ZoneRow(zone: zone)
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                }
                
                // Save Button
                Button {
                    saveZones()
                } label: {
                    Text("Save Zones")
                        .primaryButtonStyle()
                }
                .disabled(maxHR.isEmpty || restingHR.isEmpty)
                .opacity(maxHR.isEmpty || restingHR.isEmpty ? 0.5 : 1)
            }
            .padding(24)
        }
        .background(Theme.backgroundSecondary)
        .navigationTitle("Heart Rate Zones")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() {
        if let max = authService.currentUser?.biometrics?.maxHeartRate {
            maxHR = "\(max)"
        }
        if let resting = authService.currentUser?.biometrics?.restingHeartRate {
            restingHR = "\(resting)"
        }
        calculateZones()
    }
    
    private func calculateZones() {
        guard let max = Int(maxHR), let resting = Int(restingHR), max > resting else {
            zones = []
            return
        }
        
        let hrr = max - resting // Heart Rate Reserve
        
        zones = [
            HRZone(number: 1, name: "Recovery", description: "Easy effort, breathing normal", 
                   minHR: resting + Int(Double(hrr) * 0.50), 
                   maxHR: resting + Int(Double(hrr) * 0.60), 
                   color: .gray),
            HRZone(number: 2, name: "Endurance", description: "Can hold conversation", 
                   minHR: resting + Int(Double(hrr) * 0.60), 
                   maxHR: resting + Int(Double(hrr) * 0.70), 
                   color: .blue),
            HRZone(number: 3, name: "Tempo", description: "Comfortably hard, few words", 
                   minHR: resting + Int(Double(hrr) * 0.70), 
                   maxHR: resting + Int(Double(hrr) * 0.80), 
                   color: .green),
            HRZone(number: 4, name: "Threshold", description: "Hard effort, short sentences", 
                   minHR: resting + Int(Double(hrr) * 0.80), 
                   maxHR: resting + Int(Double(hrr) * 0.90), 
                   color: .orange),
            HRZone(number: 5, name: "VO2 Max", description: "Maximum effort, no talking", 
                   minHR: resting + Int(Double(hrr) * 0.90), 
                   maxHR: max, 
                   color: .red)
        ]
    }
    
    private func saveZones() {
        guard let max = Int(maxHR), let resting = Int(restingHR) else { return }
        
        authService.updateUser { user in
            // Initialize biometrics if nil
            if user.biometrics == nil {
                user.biometrics = Biometrics(userId: user.id)
            }
            user.biometrics?.maxHeartRate = max
            user.biometrics?.restingHeartRate = resting
            user.biometrics?.recordedAt = Date()
        }
        
        HapticService.shared.success()
    }
}

struct HRZone: Identifiable {
    let id = UUID()
    let number: Int
    let name: String
    let description: String
    let minHR: Int
    let maxHR: Int
    let color: Color
}

struct ZoneRow: View {
    let zone: HRZone
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(zone.color)
                    .frame(width: 40, height: 40)
                
                Text("\(zone.number)")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(zone.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.text)
                
                Text(zone.description)
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
            
            Spacer()
            
            Text("\(zone.minHR)-\(zone.maxHR)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(zone.color)
        }
        .padding(12)
        .background(zone.color.opacity(0.05))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        HeartRateZonesView()
            .environmentObject(AuthService.shared)
    }
}

