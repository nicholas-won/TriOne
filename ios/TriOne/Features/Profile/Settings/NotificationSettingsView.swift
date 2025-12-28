import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationService = NotificationService.shared
    @State private var showPermissionAlert = false
    
    var body: some View {
        List {
            Section {
                // Authorization Status
                if !notificationService.isAuthorized {
                    HStack {
                        Image(systemName: "bell.slash.fill")
                            .foregroundStyle(Theme.warning)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifications Disabled")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Enable in Settings to receive workout reminders")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button("Enable") {
                            Task {
                                let granted = await notificationService.requestAuthorization()
                                if !granted {
                                    showPermissionAlert = true
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
                        Image(systemName: "bell.fill")
                            .foregroundStyle(Theme.success)
                        
                        Text("Notifications Enabled")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.success)
                    }
                }
            } header: {
                Text("Status")
            }
            
            Section {
                // Daily Workout Reminder Toggle
                Toggle(isOn: $notificationService.workoutReminderEnabled) {
                    HStack {
                        Image(systemName: "alarm.fill")
                            .foregroundStyle(Theme.primary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily Workout Reminder")
                                .font(.subheadline)
                            
                            Text("Get reminded to workout each day")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .disabled(!notificationService.isAuthorized)
                
                // Reminder Time
                if notificationService.workoutReminderEnabled {
                    DatePicker(
                        selection: $notificationService.reminderTime,
                        displayedComponents: .hourAndMinute
                    ) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(Theme.primary)
                            
                            Text("Reminder Time")
                                .font(.subheadline)
                        }
                    }
                    .disabled(!notificationService.isAuthorized)
                }
            } header: {
                Text("Workout Reminders")
            } footer: {
                Text("We'll remind you about your scheduled workouts so you never miss a training session.")
            }
            
            Section {
                // Preview what notifications look like
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    
                    NotificationPreview(
                        title: "Time to Train! 💪",
                        message: "You have a workout scheduled for today. Let's get after it!",
                        time: notificationService.reminderTime
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text("Notification Preview")
            }
        }
        .navigationTitle("Notifications")
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
        .alert("Enable Notifications", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To receive workout reminders, please enable notifications in your device settings.")
        }
    }
}

struct NotificationPreview: View {
    let title: String
    let message: String
    let time: Date
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // App Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.primary)
                    .frame(width: 40, height: 40)
                
                Image(systemName: "figure.run")
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("TRIONE")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.textSecondary)
                    
                    Spacer()
                    
                    Text(time.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(Theme.textMuted)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.text)
                
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(Theme.backgroundSecondary)
        .cornerRadius(16)
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}

