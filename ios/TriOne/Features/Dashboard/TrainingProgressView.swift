import SwiftUI

struct TrainingProgressView: View {
    let plan: TrainingProgressPlan
    
    var body: some View {
        VStack(spacing: 16) {
            // Current Phase
            currentPhaseCard
            
            // Weekly Progress
            weeklyProgressCard
        }
    }
    
    // MARK: - Race Countdown
    
    private var raceCountdownCard: some View {
        HStack(spacing: 16) {
            // Days remaining circle
            ZStack {
                Circle()
                    .stroke(Theme.border, lineWidth: 4)
                    .frame(width: 72, height: 72)
                
                Circle()
                    .trim(from: 0, to: plan.progressPercent)
                    .stroke(Theme.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(plan.daysUntilRace)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.text)
                    
                    Text("days")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.raceName)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                
                Text(plan.raceDate.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                
                Text(plan.raceDistanceType)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.primary.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Current Phase
    
    private var currentPhaseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Training Phase")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textSecondary)
                
                Spacer()
                
                Text("Week \(plan.currentWeek) of \(plan.totalWeeks)")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
            
            // Phase Progress Bar
            HStack(spacing: 4) {
                ForEach(TrainingPhase.allCases, id: \.self) { phase in
                    PhaseSegment(
                        phase: phase,
                        isCurrent: phase == plan.currentPhase,
                        isComplete: phase.rawValue < plan.currentPhase.rawValue
                    )
                }
            }
            
            // Current Phase Info
            HStack(spacing: 12) {
                Image(systemName: plan.currentPhase.icon)
                    .font(.title2)
                    .foregroundStyle(plan.currentPhase.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.currentPhase.displayName)
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    
                    Text(plan.currentPhase.description)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Weekly Progress
    
    private var weeklyProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Week's Focus")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textSecondary)
                
                Spacer()
                
                Text(plan.currentWeekFocus)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(plan.currentPhase.color)
            }
            
            // Week at a glance
            HStack(spacing: 8) {
                WeekDayIndicator(day: "M", hasWorkout: true, isComplete: true, type: .swim)
                WeekDayIndicator(day: "T", hasWorkout: true, isComplete: true, type: .bike)
                WeekDayIndicator(day: "W", hasWorkout: true, isComplete: false, type: .run)
                WeekDayIndicator(day: "T", hasWorkout: false, isComplete: false, type: nil)
                WeekDayIndicator(day: "F", hasWorkout: true, isComplete: false, type: .swim)
                WeekDayIndicator(day: "S", hasWorkout: true, isComplete: false, type: .bike)
                WeekDayIndicator(day: "S", hasWorkout: false, isComplete: false, type: nil)
            }
            
            // Volume summary
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Planned")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                    
                    Text(plan.formattedWeeklyVolume)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.text)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Completed")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                    
                    Text(plan.formattedCompletedVolume)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.success)
                }
                
                Spacer()
                
                // Progress percentage
                Text("\(Int(plan.weekCompletionPercent * 100))%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(plan.weekCompletionPercent >= 0.8 ? Theme.success : Theme.text)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Phase Segment

struct PhaseSegment: View {
    let phase: TrainingPhase
    let isCurrent: Bool
    let isComplete: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(fillColor)
                .frame(height: 8)
                .cornerRadius(4)
            
            Text(phase.shortName)
                .font(.caption2)
                .foregroundStyle(isCurrent ? phase.color : Theme.textMuted)
        }
    }
    
    private var fillColor: Color {
        if isComplete {
            return phase.color
        } else if isCurrent {
            return phase.color.opacity(0.5)
        } else {
            return Theme.border
        }
    }
}

// MARK: - Week Day Indicator

struct WeekDayIndicator: View {
    let day: String
    let hasWorkout: Bool
    let isComplete: Bool
    let type: WorkoutType?
    
    var body: some View {
        VStack(spacing: 4) {
            Text(day)
                .font(.caption2)
                .foregroundStyle(Theme.textMuted)
            
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 32, height: 32)
                
                if hasWorkout {
                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    } else if let type = type {
                        Image(systemName: type.icon)
                            .font(.caption)
                            .foregroundStyle(type.color)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var backgroundColor: Color {
        if isComplete {
            return Theme.success
        } else if hasWorkout {
            return type?.color.opacity(0.15) ?? Theme.backgroundSecondary
        } else {
            return Theme.backgroundSecondary
        }
    }
}

// MARK: - Training Phase

enum TrainingPhase: Int, CaseIterable {
    case base = 0
    case build = 1
    case peak = 2
    case taper = 3
    
    var displayName: String {
        switch self {
        case .base: return "Base Phase"
        case .build: return "Build Phase"
        case .peak: return "Peak Phase"
        case .taper: return "Taper Phase"
        }
    }
    
    var shortName: String {
        switch self {
        case .base: return "Base"
        case .build: return "Build"
        case .peak: return "Peak"
        case .taper: return "Taper"
        }
    }
    
    var description: String {
        switch self {
        case .base: return "Building aerobic foundation and endurance"
        case .build: return "Increasing intensity and race-specific work"
        case .peak: return "Maximum training load and race simulation"
        case .taper: return "Reducing volume while maintaining intensity"
        }
    }
    
    var icon: String {
        switch self {
        case .base: return "arrow.up.right"
        case .build: return "flame.fill"
        case .peak: return "mountain.2.fill"
        case .taper: return "leaf.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .base: return Theme.primary
        case .build: return Theme.warning
        case .peak: return Theme.error
        case .taper: return Theme.success
        }
    }
}

// MARK: - Training Progress Plan Model (for UI display)

struct TrainingProgressPlan {
    let id: String
    let raceName: String
    let raceDate: Date
    let raceDistanceType: String
    let startDate: Date
    let currentPhase: TrainingPhase
    let currentWeek: Int
    let totalWeeks: Int
    let currentWeekFocus: String
    let weeklyVolumeSeconds: Int
    let completedVolumeSeconds: Int
    
    var daysUntilRace: Int {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: raceDate).day ?? 0
        return max(0, days)
    }
    
    var progressPercent: Double {
        let totalDays = Calendar.current.dateComponents([.day], from: startDate, to: raceDate).day ?? 1
        let daysElapsed = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return min(1, max(0, Double(daysElapsed) / Double(totalDays)))
    }
    
    var weekCompletionPercent: Double {
        guard weeklyVolumeSeconds > 0 else { return 0 }
        return min(1, Double(completedVolumeSeconds) / Double(weeklyVolumeSeconds))
    }
    
    var formattedWeeklyVolume: String {
        formatDuration(weeklyVolumeSeconds)
    }
    
    var formattedCompletedVolume: String {
        formatDuration(completedVolumeSeconds)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    // Mock data
    static var mock: TrainingProgressPlan {
        TrainingProgressPlan(
            id: "mock-plan-1",
            raceName: "IRONMAN 70.3 Chattanooga",
            raceDate: Calendar.current.date(byAdding: .day, value: 84, to: Date())!,
            raceDistanceType: "70.3",
            startDate: Calendar.current.date(byAdding: .day, value: -28, to: Date())!,
            currentPhase: .build,
            currentWeek: 5,
            totalWeeks: 16,
            currentWeekFocus: "Threshold Development",
            weeklyVolumeSeconds: 7 * 3600, // 7 hours
            completedVolumeSeconds: 4 * 3600 + 30 * 60 // 4.5 hours
        )
    }
}

#Preview {
    ScrollView {
        TrainingProgressView(plan: .mock)
            .padding(24)
    }
    .background(Theme.backgroundSecondary)
}

