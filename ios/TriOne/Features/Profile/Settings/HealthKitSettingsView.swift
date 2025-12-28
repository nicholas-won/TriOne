import SwiftUI

struct HealthKitSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var healthService = HealthKitService.shared
    @State private var showPermissionAlert = false
    @State private var restingHR: Int?
    @State private var vo2Max: Double?
    @State private var isLoadingStats = false
    
    var body: some View {
        List {
            // Authorization Status
            Section {
                if !healthService.isAuthorized {
                    HStack {
                        Image(systemName: "heart.slash.fill")
                            .foregroundStyle(Theme.error)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Not Connected")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Connect to Apple Health to sync your workouts")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button("Connect") {
                            Task {
                                let granted = await healthService.requestAuthorization()
                                if !granted {
                                    showPermissionAlert = true
                                } else {
                                    await loadHealthData()
                                }
                            }
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.primary)
                        .cornerRadius(16)
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Theme.error)
                        
                        Text("Connected to Apple Health")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.success)
                    }
                }
            } header: {
                Text("Connection Status")
            }
            
            // Auto-Sync Toggle
            Section {
                Toggle(isOn: $healthService.autoSyncEnabled) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(Theme.primary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Sync Workouts")
                                .font(.subheadline)
                            
                            Text("Automatically save completed workouts to Apple Health")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .disabled(!healthService.isAuthorized)
            } header: {
                Text("Sync Settings")
            } footer: {
                Text("When enabled, your completed TriOne workouts will automatically appear in Apple Health and the Fitness app.")
            }
            
            // Health Data
            if healthService.isAuthorized {
                Section {
                    if isLoadingStats {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        HealthDataRow(
                            icon: "heart.fill",
                            title: "Resting Heart Rate",
                            value: restingHR.map { "\($0) bpm" } ?? "Not available",
                            color: Theme.error
                        )
                        
                        HealthDataRow(
                            icon: "lungs.fill",
                            title: "VO2 Max",
                            value: vo2Max.map { String(format: "%.1f mL/kg/min", $0) } ?? "Not available",
                            color: Theme.primary
                        )
                    }
                } header: {
                    Text("Your Health Data")
                } footer: {
                    Text("This data is read from Apple Health and can help personalize your training.")
                }
            }
            
            // What We Access
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    AccessItemRow(icon: "figure.run", title: "Workouts", description: "Read & Write")
                    AccessItemRow(icon: "heart.fill", title: "Heart Rate", description: "Read")
                    AccessItemRow(icon: "location.fill", title: "Distance", description: "Read & Write")
                    AccessItemRow(icon: "flame.fill", title: "Active Energy", description: "Read & Write")
                    AccessItemRow(icon: "lungs.fill", title: "VO2 Max", description: "Read")
                }
                .padding(.vertical, 8)
            } header: {
                Text("Data We Access")
            } footer: {
                Text("You can manage these permissions in Settings → Privacy & Security → Health → TriOne")
            }
        }
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.text)
                        .frame(width: 40, height: 40)
                        .background(Theme.backgroundSecondary)
                        .clipShape(Circle())
                }
            }
        }
        .task {
            healthService.checkAuthorizationStatus()
            if healthService.isAuthorized {
                await loadHealthData()
            }
        }
        .alert("Enable Health Access", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To sync workouts with Apple Health, please enable access in your device settings.")
        }
    }
    
    private func loadHealthData() async {
        isLoadingStats = true
        
        async let hr = healthService.fetchRestingHeartRate()
        async let vo2 = healthService.fetchVO2Max()
        
        restingHR = await hr
        vo2Max = await vo2
        
        isLoadingStats = false
    }
}

struct HealthDataRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.text)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(value == "Not available" ? Theme.textMuted : Theme.text)
        }
    }
}

struct AccessItemRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.primary)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.text)
            
            Spacer()
            
            Text(description)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)
        }
    }
}

#Preview {
    NavigationStack {
        HealthKitSettingsView()
    }
}

