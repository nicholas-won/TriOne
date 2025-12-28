import SwiftUI

struct BaselinesSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    
    @State private var swimMinutes = ""
    @State private var swimSeconds = ""
    @State private var bikeFTP = ""
    @State private var runMinutes = ""
    @State private var runSeconds = ""
    @State private var showSaveSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Info
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Theme.primary)
                    
                    Text("Your baselines help us personalize your training intensity. Update these whenever you complete a test or notice significant improvement.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(16)
                .background(Theme.primary.opacity(0.05))
                .cornerRadius(12)
                
                // Swim CSS
                BaselineInputCard(
                    icon: "drop.fill",
                    iconColor: Theme.swim,
                    title: "Swim CSS (100m)",
                    subtitle: "Critical Swim Speed - your sustainable pace"
                ) {
                    HStack(spacing: 8) {
                        TextField("2", text: $swimMinutes)
                            .frame(width: 60)
                            .multilineTextAlignment(.center)
                        
                        Text(":")
                            .foregroundStyle(Theme.textMuted)
                        
                        TextField("00", text: $swimSeconds)
                            .frame(width: 60)
                            .multilineTextAlignment(.center)
                        
                        Text("min/100m")
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                
                // Bike FTP
                BaselineInputCard(
                    icon: "bicycle",
                    iconColor: Theme.bike,
                    title: "Bike FTP",
                    subtitle: "Functional Threshold Power - 60 min max effort"
                ) {
                    HStack(spacing: 8) {
                        TextField("200", text: $bikeFTP)
                            .frame(width: 80)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                        
                        Text("watts")
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                
                // Run Threshold
                BaselineInputCard(
                    icon: "figure.run",
                    iconColor: Theme.run,
                    title: "Run Threshold Pace",
                    subtitle: "Your sustainable 60-minute pace"
                ) {
                    HStack(spacing: 8) {
                        TextField("8", text: $runMinutes)
                            .frame(width: 60)
                            .multilineTextAlignment(.center)
                        
                        Text(":")
                            .foregroundStyle(Theme.textMuted)
                        
                        TextField("00", text: $runSeconds)
                            .frame(width: 60)
                            .multilineTextAlignment(.center)
                        
                        Text("min/mi")
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                
                // Save Button
                Button {
                    saveBaselines()
                } label: {
                    Text("Save Changes")
                        .primaryButtonStyle()
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .background(Theme.backgroundSecondary)
        .navigationTitle("Update Baselines")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentBaselines()
        }
        .alert("Saved!", isPresented: $showSaveSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your baselines have been updated. Your future workouts will be adjusted accordingly.")
        }
    }
    
    private func loadCurrentBaselines() {
        guard let user = authService.currentUser,
              let biometrics = user.biometrics else { return }
        
        // Swim CSS (seconds per 100m)
        if let css = biometrics.criticalSwimSpeed {
            let totalSeconds = Int(css)
            swimMinutes = "\(totalSeconds / 60)"
            swimSeconds = String(format: "%02d", totalSeconds % 60)
        }
        
        // Bike FTP (watts)
        if let ftp = biometrics.functionalThresholdPower {
            bikeFTP = "\(ftp)"
        }
        
        // Run Threshold Pace (seconds per mile)
        if let runPace = biometrics.thresholdRunPace {
            runMinutes = "\(runPace / 60)"
            runSeconds = String(format: "%02d", runPace % 60)
        }
    }
    
    private func saveBaselines() {
        var newSwimCSS: Double?
        var newFTP: Int?
        var newThresholdPace: Int?
        
        // Convert swim input to seconds
        if let mins = Int(swimMinutes) {
            let secs = Int(swimSeconds) ?? 0
            newSwimCSS = Double(mins * 60 + secs)
        }
        
        // FTP in watts
        if let ftp = Int(bikeFTP) {
            newFTP = ftp
        }
        
        // Convert run input to seconds
        if let mins = Int(runMinutes) {
            let secs = Int(runSeconds) ?? 0
            newThresholdPace = mins * 60 + secs
        }
        
        authService.updateBiometrics(
            criticalSwimSpeed: newSwimCSS,
            functionalThresholdPower: newFTP,
            thresholdRunPace: newThresholdPace
        )
        
        HapticService.shared.success()
        showSaveSuccess = true
    }
}

struct BaselineInputCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            
            HStack {
                content
            }
            .padding(16)
            .background(Theme.backgroundSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
}

#Preview {
    NavigationStack {
        BaselinesSettingsView()
            .environmentObject(AuthService.shared)
    }
}

