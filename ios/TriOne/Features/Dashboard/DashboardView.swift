import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var workoutService = WorkoutService.shared
    
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
                    
                    // Week View
                    WeekCalendarView(workouts: workoutService.weekWorkouts)
                        .padding(.horizontal, 24)
                    
                    // Training Progress (if user has a plan)
                    TrainingProgressView(plan: .mock)
                        .padding(.horizontal, 24)
                    
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
}

// MARK: - Week Calendar
struct WeekCalendarView: View {
    let workouts: [Workout]
    
    private var weekDays: [(date: Date, workout: Workout?)] {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)!
            let workout = workouts.first { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
            return (date, workout)
        }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(weekDays, id: \.date) { day in
                    WeekDayCard(date: day.date, workout: day.workout)
                }
            }
        }
    }
}

struct WeekDayCard: View {
    let date: Date
    let workout: Workout?
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var dayName: String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }
    
    private var dayNumber: String {
        date.formatted(.dateTime.day())
    }
    
    var body: some View {
        NavigationLink(destination: workout.map { WorkoutDetailView(workout: $0) }) {
            VStack(spacing: 8) {
                Text(dayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isToday ? .white.opacity(0.7) : Theme.textMuted)
                
                Text(dayNumber)
                    .font(.headline)
                    .foregroundStyle(isToday ? .white : Theme.text)
                
                if let workout = workout {
                    if workout.status == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(isToday ? .white : Theme.success)
                    } else if workout.status == .missed {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.error)
                    } else {
                        ZStack {
                            Circle()
                                .fill(isToday ? Color.white.opacity(0.2) : workout.color.opacity(0.2))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: workout.icon)
                                .font(.caption)
                                .foregroundStyle(isToday ? .white : workout.color)
                        }
                    }
                } else {
                    Circle()
                        .fill(Theme.border)
                        .frame(width: 24, height: 24)
                }
            }
            .frame(width: 52)
            .padding(.vertical, 12)
            .background(isToday ? Theme.primary : Theme.backgroundSecondary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .disabled(workout == nil)
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

#Preview {
    DashboardView()
        .environmentObject(AppState())
        .environmentObject(AuthService.shared)
}

