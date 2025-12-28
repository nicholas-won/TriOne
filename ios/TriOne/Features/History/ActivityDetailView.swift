import SwiftUI

struct ActivityDetailView: View {
    let activity: Activity
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Stats Grid
                statsSection
                
                // Feedback
                if activity.rating != nil || activity.rpe != nil {
                    feedbackSection
                }
                
                // Map Placeholder
                mapSection
            }
        }
        .background(Theme.backgroundSecondary)
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
                        .background(Color.white.opacity(0.8))
                        .clipShape(Circle())
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        // Share action
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive) {
                        // Delete action
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.text)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.8))
                        .clipShape(Circle())
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(activity.workoutType.color)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: activity.workoutType.icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.workoutType.displayName.uppercased())
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    
                    Text(activity.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.text)
                }
                
                Spacer()
            }
            
            // Date and Time
            HStack(spacing: 16) {
                Label(
                    activity.completedAt.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar"
                )
                
                Label(
                    activity.completedAt.formatted(date: .omitted, time: .shortened),
                    systemImage: "clock"
                )
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(24)
        .background(activity.workoutType.color.opacity(0.1))
    }
    
    // MARK: - Stats
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.headline)
                .foregroundStyle(Theme.text)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                DetailStatCard(
                    icon: "clock.fill",
                    label: "Duration",
                    value: activity.formattedDuration,
                    color: Theme.primary
                )
                
                if let distance = activity.formattedDistance {
                    DetailStatCard(
                        icon: "location.fill",
                        label: "Distance",
                        value: distance,
                        color: Theme.bike
                    )
                }
                
                if let hr = activity.avgHeartRate {
                    DetailStatCard(
                        icon: "heart.fill",
                        label: "Avg Heart Rate",
                        value: "\(hr) bpm",
                        color: Theme.error
                    )
                }
                
                // Pace for run/swim
                if activity.workoutType == .run, let meters = activity.distanceMeters, meters > 0 {
                    let paceSecondsPerMile = Double(activity.durationSeconds) / (Double(meters) / 1609.34)
                    let paceMinutes = Int(paceSecondsPerMile) / 60
                    let paceSeconds = Int(paceSecondsPerMile) % 60
                    
                    DetailStatCard(
                        icon: "speedometer",
                        label: "Avg Pace",
                        value: String(format: "%d:%02d /mi", paceMinutes, paceSeconds),
                        color: Theme.run
                    )
                }
            }
        }
        .padding(24)
        .background(Color.white)
    }
    
    // MARK: - Feedback
    
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Feedback")
                .font(.headline)
                .foregroundStyle(Theme.text)
            
            HStack(spacing: 24) {
                if let rating = activity.rating {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How it felt")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        
                        HStack(spacing: 8) {
                            Image(systemName: ratingIcon(rating))
                                .foregroundStyle(ratingColor(rating))
                            
                            Text(rating.capitalized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.text)
                        }
                    }
                }
                
                if let rpe = activity.rpe {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RPE Score")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        
                        HStack(spacing: 8) {
                            Text("\(rpe)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(rpeColor(rpe))
                            
                            Text("/ 10")
                                .font(.caption)
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding(24)
        .background(Color.white)
    }
    
    // MARK: - Map
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Route")
                .font(.headline)
                .foregroundStyle(Theme.text)
            
            // Map placeholder
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.backgroundSecondary)
                .frame(height: 200)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.textMuted)
                        
                        Text("Route data not available")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                )
        }
        .padding(24)
        .background(Color.white)
    }
    
    // MARK: - Helpers
    
    private func ratingIcon(_ rating: String) -> String {
        switch rating.lowercased() {
        case "easier": return "arrow.down.circle.fill"
        case "same": return "equal.circle.fill"
        case "harder": return "arrow.up.circle.fill"
        default: return "circle.fill"
        }
    }
    
    private func ratingColor(_ rating: String) -> Color {
        switch rating.lowercased() {
        case "easier": return Theme.success
        case "same": return Theme.primary
        case "harder": return Theme.warning
        default: return Theme.textMuted
        }
    }
    
    private func rpeColor(_ rpe: Int) -> Color {
        switch rpe {
        case 1...3: return Theme.success
        case 4...6: return Theme.warning
        case 7...8: return .orange
        default: return Theme.error
        }
    }
}

struct DetailStatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.backgroundSecondary)
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        ActivityDetailView(activity: Activity(
            id: "1",
            workoutId: "w1",
            workoutType: .run,
            title: "Morning Run",
            completedAt: Date(),
            durationSeconds: 2700,
            distanceMeters: 8000,
            avgHeartRate: 145,
            rating: "same",
            rpe: 6
        ))
    }
}

