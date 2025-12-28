import SwiftUI
import Combine

struct WeekGroup: Identifiable {
    let id: String
    let weekNumber: Int
    let phase: String?
    let startDate: Date
    let endDate: Date
    let workouts: [Workout]
    
    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)
        return "\(start) - \(end)"
    }
    
    var totalPlannedDuration: Int {
        workouts.reduce(0) { $0 + $1.structure.totalDuration }
    }
    
    var formattedTotalDuration: String {
        let hours = totalPlannedDuration / 3600
        let minutes = (totalPlannedDuration % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct DayWorkout: Identifiable {
    let id: String
    let date: Date
    let workout: Workout?
    let isRestDay: Bool
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

@MainActor
class PlanViewModel: ObservableObject {
    @Published var weekGroups: [WeekGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedMonth: Date = Date()
    @Published var planStartDate: Date?
    @Published var raceDate: Date?
    @Published var shouldScrollToToday = false
    @Published var isMaintenanceMode = false
    
    private let apiService = APIService.shared
    private let workoutService = WorkoutService.shared
    private let authService = AuthService.shared
    
    // MARK: - Load Data
    
    func loadWorkouts() async {
        isLoading = true
        defer { isLoading = false }
        
        // Fetch active training plan to get start date
        var planStart: Date?
        var race: Date?
        
        if !authService.isDevMode {
            do {
                if let plan = try await apiService.getActivePlan() {
                    let dateFormatter = ISO8601DateFormatter()
                    dateFormatter.formatOptions = [.withFullDate]
                    planStart = dateFormatter.date(from: plan.startDate)
                    race = dateFormatter.date(from: plan.raceDate)
                    
                    // Check if race has passed - if so, we should create a new plan
                    if let raceDate = race, raceDate < Date() {
                        // Race has passed - plan should be reset for next race
                        // For now, we'll still show the old plan, but in the future this could trigger plan regeneration
                        print("Race has passed. Consider creating a new plan.")
                    }
                }
            } catch {
                print("Failed to fetch training plan: \(error)")
            }
        }
        
        // Use plan start date or default to recent Monday for dev mode
        let calendar = Calendar.current
        let defaultStart: Date
        if let planStart = planStart {
            defaultStart = planStart
        } else {
            // For dev mode, use the most recent Monday (or today if it's Monday)
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            components.weekday = 2 // Monday
            defaultStart = calendar.date(from: components) ?? Date()
        }
        
        planStartDate = defaultStart
        raceDate = race
        
        // Check if we're in maintenance mode (no race selected)
        isMaintenanceMode = authService.currentUser?.primaryRaceId == nil
        
        // Calculate date range (3 months back from plan start, 6 months forward from plan start or race date)
        let rangeStart = calendar.date(byAdding: .month, value: -3, to: defaultStart)!
        let rangeEnd: Date
        if let race = race {
            // Show up to 1 month after race date
            rangeEnd = calendar.date(byAdding: .month, value: 1, to: race)!
        } else {
            // Default to 6 months from plan start
            rangeEnd = calendar.date(byAdding: .month, value: 6, to: defaultStart)!
        }
        
        if authService.isDevMode {
            // Generate mock workouts starting from plan start date
            let mockWorkouts = generateMockWorkouts(startDate: defaultStart, endDate: rangeEnd)
            weekGroups = groupWorkoutsByWeek(
                workouts: mockWorkouts,
                planStartDate: defaultStart,
                startDate: rangeStart,
                endDate: rangeEnd
            )
        } else {
            // Real API call
            do {
                let workouts = try await apiService.fetchWorkouts(startDate: rangeStart, endDate: rangeEnd)
                let workoutModels = workouts.map { Workout.from(response: $0) }
                weekGroups = groupWorkoutsByWeek(
                    workouts: workoutModels,
                    planStartDate: defaultStart,
                    startDate: rangeStart,
                    endDate: rangeEnd
                )
            } catch {
                print("Failed to fetch workouts: \(error)")
                errorMessage = "Failed to load workouts"
                weekGroups = []
            }
        }
    }
    
    // MARK: - Mock Data Generation (Dev Mode)
    
    private func generateMockWorkouts(startDate: Date, endDate: Date) -> [Workout] {
        var workouts: [Workout] = []
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: startDate)
        
        // Realistic weekly pattern: Mon-Sat workouts, Sunday rest
        // Pattern: Mon=Swim, Tue=Bike, Wed=Run, Thu=Swim, Fri=Bike, Sat=Run
        let weeklyPattern: [WorkoutType?] = [.swim, .bike, .run, .swim, .bike, .run, nil] // Sun is rest
        
        // Ensure we start on Monday (plan start date should already be Monday, but double-check)
        while calendar.component(.weekday, from: currentDate) != 2 { // 2 = Monday
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        var weekOffset = 0
        
        while currentDate <= endDate {
            for (dayIndex, workoutType) in weeklyPattern.enumerated() {
                guard currentDate <= endDate else { break }
                
                if let type = workoutType {
                    // Determine status based on date
                    let isPast = currentDate < Date()
                    let isToday = calendar.isDateInToday(currentDate)
                    
                    var status: WorkoutStatus = .scheduled
                    if isPast && !isToday {
                        // Past workouts: mix of completed and missed
                        status = (weekOffset % 3 == 0) ? .completed : .scheduled
                    } else if isToday {
                        status = .scheduled
                    }
                    
                    // Create workout for this day
                    let workout = Workout.mock(
                        id: "mock-\(currentDate.timeIntervalSince1970)",
                        type: type,
                        date: currentDate,
                        status: status
                    )
                    workouts.append(workout)
                }
                
                // Move to next day
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            weekOffset += 1
        }
        
        return workouts
    }
    
    // MARK: - Grouping Logic
    
    private func groupWorkoutsByWeek(workouts: [Workout], planStartDate: Date, startDate: Date, endDate: Date) -> [WeekGroup] {
        let calendar = Calendar.current
        
        // Start from the plan start date (Week 1)
        var currentDate = calendar.startOfDay(for: planStartDate)
        
        // If we need to show weeks before the plan start, go back to the range start
        let rangeStart = calendar.startOfDay(for: startDate)
        if currentDate > rangeStart {
            // Go back to find the Monday of the week containing rangeStart
            var weekStart = rangeStart
            while calendar.component(.weekday, from: weekStart) != 2 { // 2 = Monday
                weekStart = calendar.date(byAdding: .day, value: -1, to: weekStart)!
            }
            currentDate = weekStart
        }
        
        var weekGroups: [WeekGroup] = []
        var weekNumber = 1
        
        // Calculate which week number the plan start date is
        if currentDate < planStartDate {
            // We're showing weeks before the plan started
            let daysBeforePlanStart = calendar.dateComponents([.day], from: currentDate, to: planStartDate).day ?? 0
            weekNumber = 1 - (daysBeforePlanStart / 7)
            // Adjust to start at Week 1 when we reach planStartDate
        }
        
        while currentDate <= endDate {
            let weekStart = currentDate
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            
            // Get workouts for this week
            let weekWorkouts = workouts.filter { workout in
                let workoutDate = calendar.startOfDay(for: workout.scheduledDate)
                return workoutDate >= weekStart && workoutDate <= weekEnd
            }
            
            // Calculate week number from plan start
            let displayWeekNumber: Int
            if weekStart >= planStartDate {
                // Calculate week number from plan start (Week 1 starts on planStartDate)
                let daysFromPlanStart = calendar.dateComponents([.day], from: planStartDate, to: weekStart).day ?? 0
                displayWeekNumber = (daysFromPlanStart / 7) + 1
            } else {
                // Before plan start - show as 0 (will be displayed as "Pre-Plan")
                displayWeekNumber = 0
            }
            
            // Determine phase and week number based on maintenance mode
            let phase: String?
            let finalWeekNumber: Int
            
            if isMaintenanceMode {
                // Maintenance mode: no week numbers, always "Maintenance Phase"
                phase = "Maintenance Phase"
                finalWeekNumber = 0 // 0 indicates no week number should be shown
            } else {
                // Race prep mode: show week numbers and phases
                phase = displayWeekNumber > 0 ? determinePhase(for: displayWeekNumber) : nil
                finalWeekNumber = displayWeekNumber > 0 ? displayWeekNumber : weekNumber
            }
            
            let group = WeekGroup(
                id: isMaintenanceMode ? "maintenance-\(weekNumber)" : "week-\(finalWeekNumber > 0 ? finalWeekNumber : weekNumber)",
                weekNumber: finalWeekNumber,
                phase: phase,
                startDate: weekStart,
                endDate: weekEnd,
                workouts: weekWorkouts.sorted { $0.scheduledDate < $1.scheduledDate }
            )
            
            weekGroups.append(group)
            
            // Move to next week
            currentDate = calendar.date(byAdding: .day, value: 7, to: currentDate)!
            weekNumber += 1
        }
        
        return weekGroups
    }
    
    private func determinePhase(for weekNumber: Int) -> String? {
        // Simplified phase logic - in real app, this would come from the training plan
        if weekNumber <= 4 {
            return "Base Phase"
        } else if weekNumber <= 12 {
            return "Build Phase"
        } else if weekNumber <= 16 {
            return "Peak Phase"
        } else {
            return "Taper Phase"
        }
    }
    
    // MARK: - Day Workouts
    
    func dayWorkouts(for week: WeekGroup) -> [DayWorkout] {
        let calendar = Calendar.current
        var dayWorkouts: [DayWorkout] = []
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: week.startDate) else {
                continue
            }
            
            let workout = week.workouts.first { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
            let isRestDay = workout == nil
            
            dayWorkouts.append(DayWorkout(
                id: "\(week.id)-\(dayOffset)",
                date: date,
                workout: workout,
                isRestDay: isRestDay
            ))
        }
        
        return dayWorkouts
    }
    
    // MARK: - Month Navigation
    
    func previousMonth() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
    
    func nextMonth() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
    
    var formattedMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }
    
    // MARK: - Scroll to Current Week
    
    func currentWeekIndex() -> Int? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        print("🔍 Looking for week containing today: \(today)")
        print("🔍 Week groups count: \(weekGroups.count)")
        
        for (index, week) in weekGroups.enumerated() {
            let weekStart = calendar.startOfDay(for: week.startDate)
            let weekEnd = calendar.startOfDay(for: week.endDate)
            let containsToday = today >= weekStart && today <= weekEnd
            
            print("  Week \(index): \(week.id)")
            print("    Start: \(weekStart) (formatted: \(week.formattedDateRange))")
            print("    End: \(weekEnd)")
            print("    Today: \(today)")
            print("    Contains today: \(containsToday)")
            
            if containsToday {
                print("✅ Found current week at index \(index)")
                return index
            }
        }
        
        print("⚠️ No week found containing today")
        // Fallback: find the closest week
        if let closestIndex = weekGroups.enumerated().min(by: { abs($0.element.startDate.timeIntervalSince(today)) < abs($1.element.startDate.timeIntervalSince(today)) })?.offset {
            print("📍 Using closest week at index \(closestIndex)")
            return closestIndex
        }
        
        return nil
    }
}

