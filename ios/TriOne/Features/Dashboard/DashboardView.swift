import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var workoutService = WorkoutService.shared
    @State private var races: [Race] = Race.mockRaces
    
    var selectedRace: Race? {
        guard let primaryRaceId = authService.currentUser?.primaryRaceId else { return nil }
        return races.first { $0.id == primaryRaceId }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Date().formatted(date: .complete, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        
                        Text("Hi, \(authService.currentUser?.displayNameOrEmail ?? "Athlete")!")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.text)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Selected Race Info
                    if let selectedRace = selectedRace {
                        SelectedRaceInfoCard(race: selectedRace)
                            .padding(.horizontal, 24)
                        
                        // Training Progress (if user has a plan and selected race)
                        TrainingProgressView(plan: createTrainingProgressPlan(for: selectedRace))
                            .padding(.horizontal, 24)
                    }
                    
                    // Today's Workout
                    VStack(alignment: .leading, spacing: 12) {
                        if let workout = workoutService.todayWorkout {
                            TodayWorkoutCard(workout: workout)
                        } else {
                            RestDayCard()
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Weekly Summary
                    if let summary = workoutService.weeklySummary {
                        WeeklySummaryCard(summary: summary)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Color.white)
            .refreshable {
                await workoutService.loadAllData()
            }
        }
        .task {
            await workoutService.loadAllData()
        }
    }
    
    // MARK: - Helper Functions
    
    private func createTrainingProgressPlan(for race: Race) -> TrainingProgressPlan {
        // Calculate plan start date (typically 16 weeks before race, but adjust based on actual plan if available)
        let calendar = Calendar.current
        let planStartDate = calendar.date(byAdding: .weekOfYear, value: -16, to: race.date) ?? Date()
        
        // Calculate current week (simplified - would come from actual plan in real implementation)
        let daysFromStart = calendar.dateComponents([.day], from: planStartDate, to: Date()).day ?? 0
        let currentWeek = max(1, (daysFromStart / 7) + 1)
        
        // Determine phase based on week
        let currentPhase: TrainingPhase
        if currentWeek <= 4 {
            currentPhase = .base
        } else if currentWeek <= 12 {
            currentPhase = .build
        } else if currentWeek <= 16 {
            currentPhase = .peak
        } else {
            currentPhase = .taper
        }
        
        // Get distance type string (extract just the number part from displayName)
        let distanceTypeString: String
        switch race.distanceType {
        case .sprint:
            distanceTypeString = "Sprint"
        case .olympic:
            distanceTypeString = "Olympic"
        case .halfIronman:
            distanceTypeString = "70.3"
        case .fullIronman:
            distanceTypeString = "140.6"
        }
        
        return TrainingProgressPlan(
            id: "plan-\(race.id)",
            raceName: race.name,
            raceDate: race.date,
            raceDistanceType: distanceTypeString,
            startDate: planStartDate,
            currentPhase: currentPhase,
            currentWeek: currentWeek,
            totalWeeks: 16,
            currentWeekFocus: currentPhase == .build ? "Threshold Development" : "Base Building",
            weeklyVolumeSeconds: 7 * 3600, // 7 hours (would come from actual plan)
            completedVolumeSeconds: 4 * 3600 + 30 * 60 // 4.5 hours (would come from actual data)
        )
    }
}

// MARK: - Today's Workout Card
struct TodayWorkoutCard: View {
    let workout: Workout
    
    private var isCompleted: Bool {
        workout.status == .completed
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isCompleted ? Theme.success : workout.color)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: isCompleted ? "checkmark" : workout.icon)
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(isCompleted ? "Completed" : "Today's Focus")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(isCompleted ? Theme.success : Theme.textSecondary)
                                .textCase(.uppercase)
                            
                            if isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.success)
                            }
                        }
                        
                        Text(workout.structure.title)
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                    }
                }
                
                Spacer()
                
                Text(workout.structure.formattedDuration)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
            }
            .padding(16)
            .background(isCompleted ? Theme.success.opacity(0.1) : workout.color.opacity(0.1))
            
            // Description
            Text(workout.structure.description)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            
            Divider()
            
            // Steps Preview
            HStack(spacing: 4) {
                ForEach(workout.structure.steps.prefix(3)) { step in
                    Rectangle()
                        .fill(step.isIntense ? (isCompleted ? Theme.success : workout.color) : Theme.border)
                        .frame(height: 8)
                        .cornerRadius(4)
                }
                
                if workout.structure.steps.count > 3 {
                    Text("+\(workout.structure.steps.count - 3) more")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .padding(16)
            
            // CTA
            NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                if isCompleted {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Completed")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.success)
                    .cornerRadius(10)
                } else {
                    Text("Start Workout")
                        .primaryButtonStyle()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCompleted ? Theme.success.opacity(0.3) : Theme.border, lineWidth: 1)
        )
    }
}

struct RestDayCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.success)
            
            Text("Rest Day")
                .font(.headline)
                .foregroundStyle(Theme.text)
            
            Text("Enjoy your recovery!")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Theme.backgroundSecondary)
        .cornerRadius(16)
    }
}

// MARK: - Weekly Summary
struct WeeklySummaryCard: View {
    let summary: WeeklySummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Theme.textSecondary)
            
            HStack {
                // Workouts
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(summary.completedWorkouts)/\(summary.totalWorkouts)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.text)
                    
                    Text("Workouts")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    
                    ProgressBar(progress: summary.completionRate, color: Theme.primary)
                }
                
                Divider()
                    .padding(.horizontal, 16)
                
                // Duration
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.formatDuration(summary.actualDuration))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.text)
                    
                    Text("of \(summary.formatDuration(summary.plannedDuration))")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    
                    ProgressBar(progress: min(1, summary.durationRate), color: Theme.success)
                }
            }
        }
        .padding(16)
        .background(Theme.backgroundSecondary)
        .cornerRadius(16)
    }
}

struct ProgressBar: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 8)
                    .cornerRadius(4)
                
                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * progress, height: 8)
                    .cornerRadius(4)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Selected Race Info Card

struct SelectedRaceInfoCard: View {
    let race: Race
    
    var body: some View {
        HStack(spacing: 12) {
            // Days remaining circle
            ZStack {
                Circle()
                    .stroke(Theme.border, lineWidth: 3)
                    .frame(width: 48, height: 48)
                
                VStack(spacing: 0) {
                    Text("\(race.daysUntil)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.text)
                    
                    Text("days")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.primary)
                    
                    Text("Next Race")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textMuted)
                        .textCase(.uppercase)
                }
                
                Text(race.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(race.location)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                    
                    Text(race.formattedDate)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.primary)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
        .environmentObject(AuthService.shared)
}

