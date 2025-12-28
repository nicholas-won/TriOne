import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @State private var showSignOutAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Theme.primary.opacity(0.2))
                                .frame(width: 96, height: 96)
                            
                            Text(authService.currentUser?.initials ?? "A")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.primary)
                        }
                        
                        VStack(spacing: 4) {
                            Text(authService.currentUser?.displayNameOrEmail ?? "Athlete")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.text)
                            
                            Text(authService.currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        
                        HStack(spacing: 8) {
                            Capsule()
                                .fill(Theme.primary.opacity(0.1))
                                .frame(height: 32)
                                .overlay(
                                    Text(authService.currentUser?.experienceLevel?.displayName ?? "Finisher")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Theme.primary)
                                )
                                .fixedSize()
                            
                            if authService.isDevMode {
                                Capsule()
                                    .fill(Color.orange.opacity(0.1))
                                    .frame(height: 32)
                                    .overlay(
                                        Text("🚧 Dev Mode")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.orange)
                                    )
                                    .fixedSize()
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    
                    // Settings Sections
                    VStack(spacing: 16) {
                        // Subscription
                        SettingsSection(title: "Subscription") {
                            SettingsRow(
                                icon: "creditcard",
                                title: "Plan",
                                subtitle: subscriptionStatus
                            ) {}
                        }
                        
                        // Training
                        SettingsSection(title: "Training") {
                            NavigationLink(destination: BaselinesSettingsView()) {
                                SettingsRowContent(
                                    icon: "gauge.medium",
                                    title: "Update Baselines",
                                    subtitle: "CSS, FTP, Threshold Pace"
                                )
                            }
                            
                            NavigationLink(destination: UnitsSettingsView()) {
                                SettingsRowContent(
                                    icon: "ruler",
                                    title: "Units",
                                    subtitle: authService.currentUser?.unitPreference.displayName ?? "Imperial"
                                )
                            }
                            
                            NavigationLink(destination: HeartRateZonesView()) {
                                SettingsRowContent(
                                    icon: "heart",
                                    title: "Heart Rate Zones",
                                    subtitle: "Configure your zones"
                                )
                            }
                        }
                        
                        // Privacy & Notifications
                        SettingsSection(title: "Preferences") {
                            NavigationLink(destination: NotificationSettingsView()) {
                                SettingsRowContent(
                                    icon: "bell.badge",
                                    title: "Notifications",
                                    subtitle: "Workout reminders"
                                )
                            }
                            
                            SettingsToggleRow(
                                icon: "eye.slash",
                                title: "Private Profile",
                                subtitle: "Hide your activities from others",
                                isOn: .constant(authService.currentUser?.isPrivate ?? false)
                            )
                        }
                        
                        // Stats
                        SettingsSection(title: "Analytics") {
                            NavigationLink(destination: StatsView()) {
                                SettingsRowContent(
                                    icon: "chart.bar.fill",
                                    title: "Training Statistics",
                                    subtitle: "View your progress and PRs"
                                )
                            }
                        }
                        
                        // Integrations
                        SettingsSection(title: "Integrations") {
                            NavigationLink(destination: HealthKitSettingsView()) {
                                SettingsRowContent(
                                    icon: "heart.text.square",
                                    title: "Apple Health",
                                    subtitle: HealthKitService.shared.isAuthorized ? "Connected" : "Not connected"
                                )
                            }
                            
                            SettingsRow(
                                icon: "applewatch",
                                title: "Garmin Connect",
                                subtitle: "Not connected"
                            ) {}
                        }
                        
                        // Support
                        SettingsSection(title: "Support") {
                            SettingsRow(icon: "questionmark.circle", title: "Help Center") {}
                            SettingsRow(icon: "envelope", title: "Contact Support") {}
                            SettingsRow(icon: "doc.text", title: "Terms of Service") {}
                            SettingsRow(icon: "shield.checkered", title: "Privacy Policy") {}
                        }
                    }
                    .padding(.top, 16)
                    
                    // Sign Out
                    Button {
                        showSignOutAlert = true
                    } label: {
                        Text("Sign Out")
                            .font(.headline)
                            .foregroundStyle(Theme.error)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.error, lineWidth: 1)
                            )
                    }
                    .padding(24)
                    
                    // Version
                    Text("TriOne v1.0.0\(authService.isDevMode ? " (Dev)" : "")")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                        .padding(.bottom, 32)
                }
            }
            .background(Theme.backgroundSecondary)
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                    appState.reset()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    private var subscriptionStatus: String {
        if authService.isDevMode {
            return "Trial (Dev Mode)"
        }
        
        guard let user = authService.currentUser else { return "Inactive" }
        
        switch user.subscriptionStatus {
        case .trial:
            if let days = user.trialDaysRemaining {
                return "Trial (\(days) days left)"
            }
            return "Trial"
        case .active:
            return "Active"
        case .pastDue:
            return "Past Due"
        case .churned:
            return "Inactive"
        }
    }
}

// MARK: - Settings Components
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Theme.textMuted)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.white)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            SettingsRowContent(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsRowContent: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.backgroundSecondary)
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .foregroundStyle(Theme.textMuted)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.text)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.backgroundSecondary)
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .foregroundStyle(Theme.textMuted)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.text)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(Theme.primary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(AuthService.shared)
}

