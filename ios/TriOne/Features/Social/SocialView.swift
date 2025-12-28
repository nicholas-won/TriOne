import SwiftUI

struct SocialView: View {
    @State private var activities: [SocialActivity] = SocialActivity.mockActivities
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activity Feed")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.text)
                        
                        Text("See what your friends are up to")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    if activities.isEmpty {
                        // Empty State
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Theme.backgroundSecondary)
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "person.2")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Theme.textMuted)
                            }
                            
                            Text("No activities yet")
                                .font(.headline)
                                .foregroundStyle(Theme.text)
                            
                            Text("When your friends complete workouts, they'll show up here.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 48)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 64)
                    } else {
                        // Activity List
                        ForEach($activities) { $activity in
                            SocialActivityCard(activity: $activity)
                                .padding(.horizontal, 24)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Theme.backgroundSecondary)
            .refreshable {
                // Simulate refresh
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}

struct SocialActivityCard: View {
    @Binding var activity: SocialActivity
    
    var body: some View {
        VStack(spacing: 0) {
            // User Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.primary.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Text(activity.userName.prefix(1))
                        .font(.headline)
                        .foregroundStyle(Theme.primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.userName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.text)
                    
                    Text(activity.timeAgo)
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(activity.workoutType.color.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: activity.workoutType.icon)
                        .font(.caption)
                        .foregroundStyle(activity.workoutType.color)
                }
            }
            .padding(16)
            
            // Stats
            HStack {
                StatItem(value: activity.formattedDuration, label: "Duration")
                
                if let distance = activity.formattedDistance {
                    Divider()
                        .frame(height: 40)
                    
                    StatItem(value: distance, label: "Distance")
                }
                
                if let hr = activity.avgHeartRate {
                    Divider()
                        .frame(height: 40)
                    
                    StatItem(value: "\(hr)", label: "Avg HR")
                }
            }
            .padding(16)
            .background(Theme.backgroundSecondary)
            
            Divider()
            
            // Kudos
            HStack {
                Button {
                    HapticService.shared.light()
                    activity.hasKudos.toggle()
                    activity.kudosCount += activity.hasKudos ? 1 : -1
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: activity.hasKudos ? "heart.fill" : "heart")
                            .foregroundStyle(activity.hasKudos ? Theme.error : Theme.textMuted)
                        
                        Text(activity.kudosCount > 0 ? "\(activity.kudosCount) Kudos" : "Kudos")
                            .font(.subheadline)
                            .foregroundStyle(activity.hasKudos ? Theme.error : Theme.textSecondary)
                    }
                }
                
                Spacer()
            }
            .padding(16)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Theme.text)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Social Activity Model
struct SocialActivity: Identifiable {
    let id: String
    let userName: String
    let workoutType: WorkoutType
    let completedAt: Date
    let durationSeconds: Int
    let distanceMeters: Int?
    let avgHeartRate: Int?
    var kudosCount: Int
    var hasKudos: Bool
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: completedAt, relativeTo: Date())
    }
    
    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    var formattedDistance: String? {
        guard let meters = distanceMeters else { return nil }
        let miles = Double(meters) / 1609.34
        return String(format: "%.2f mi", miles)
    }
    
    static let mockActivities: [SocialActivity] = [
        SocialActivity(
            id: "1",
            userName: "Sarah Chen",
            workoutType: .run,
            completedAt: Date().addingTimeInterval(-2 * 3600),
            durationSeconds: 3600,
            distanceMeters: 8000,
            avgHeartRate: 145,
            kudosCount: 5,
            hasKudos: false
        ),
        SocialActivity(
            id: "2",
            userName: "Mike Johnson",
            workoutType: .bike,
            completedAt: Date().addingTimeInterval(-5 * 3600),
            durationSeconds: 5400,
            distanceMeters: 40000,
            avgHeartRate: 138,
            kudosCount: 12,
            hasKudos: true
        ),
        SocialActivity(
            id: "3",
            userName: "Emma Wilson",
            workoutType: .swim,
            completedAt: Date().addingTimeInterval(-24 * 3600),
            durationSeconds: 2700,
            distanceMeters: 2500,
            avgHeartRate: 125,
            kudosCount: 8,
            hasKudos: false
        ),
    ]
}

#Preview {
    SocialView()
}

