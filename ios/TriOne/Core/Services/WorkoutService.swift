import SwiftUI
import Combine

@MainActor
class WorkoutService: ObservableObject {
    static let shared = WorkoutService()
    
    @Published var todayWorkout: Workout?
    @Published var weekWorkouts: [Workout] = []
    @Published var weeklySummary: WeeklySummary?
    @Published var isLoading = false
    @Published var lastActivityLogId: String?
    
    private let apiService = APIService.shared
    private let completedWorkoutsKey = "completedWorkoutIds"
    private let skippedWorkoutsKey = "skippedWorkoutIds"
    
    private init() {
        loadPersistedCompletionStatus()
    }
    
    // MARK: - Persistence (for dev mode)
    
    private var completedWorkoutIds: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: completedWorkoutsKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: completedWorkoutsKey)
        }
    }
    
    private var skippedWorkoutIds: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: skippedWorkoutsKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: skippedWorkoutsKey)
        }
    }
    
    private func loadPersistedCompletionStatus() {
        // This will be applied when workouts are loaded
    }
    
    private func applyPersistedStatus(to workout: inout Workout) {
        if completedWorkoutIds.contains(workout.id) {
            workout.status = .completed
        } else if skippedWorkoutIds.contains(workout.id) {
            workout.status = .skipped
        }
    }
    
    // MARK: - Fetch Data
    
    func fetchTodayWorkout() async {
        isLoading = true
        defer { isLoading = false }
        
        if AuthService.shared.isDevMode {
            let dayOfWeek = Calendar.current.component(.weekday, from: Date()) - 1 // 0 = Sunday
            
            if dayOfWeek == 0 {
                todayWorkout = nil // Rest day
            } else {
                let types: [WorkoutType] = [.swim, .bike, .run]
                let type = types[(dayOfWeek - 1) % 3]
                var workout = Workout.mock(
                    id: "mock-workout-\(dayOfWeek)",
                    type: type,
                    date: Date(),
                    status: .scheduled
                )
                applyPersistedStatus(to: &workout)
                todayWorkout = workout
            }
            return
        }
        
        // Real API call
        do {
            if let response = try await apiService.fetchTodayWorkout() {
                todayWorkout = Workout.from(response: response)
            } else {
                todayWorkout = nil
            }
        } catch {
            print("Failed to fetch today's workout: \(error)")
            // Fall back to mock data on error
            todayWorkout = nil
        }
    }
    
    func fetchWeekWorkouts() async {
        isLoading = true
        defer { isLoading = false }
        
        if AuthService.shared.isDevMode {
            var workouts = Workout.mockWeek()
            // Apply persisted statuses
            for i in workouts.indices {
                applyPersistedStatus(to: &workouts[i])
            }
            weekWorkouts = workouts
            return
        }
        
        // Real API call
        do {
            let responses = try await apiService.fetchWeekWorkouts()
            weekWorkouts = responses.map { Workout.from(response: $0) }
        } catch {
            print("Failed to fetch week workouts: \(error)")
            weekWorkouts = []
        }
    }
    
    func fetchWeeklySummary() async {
        if AuthService.shared.isDevMode {
            let completed = weekWorkouts.filter { $0.status == .completed }
            let totalDuration = weekWorkouts.reduce(0) { $0 + $1.structure.totalDuration }
            let actualDuration = completed.reduce(0) { $0 + $1.structure.totalDuration }
            
            weeklySummary = WeeklySummary(
                plannedDuration: totalDuration,
                actualDuration: actualDuration,
                completedWorkouts: completed.count,
                totalWorkouts: weekWorkouts.count
            )
            return
        }
        
        // TODO: Implement API call for weekly summary
    }
    
    func loadAllData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchTodayWorkout() }
            group.addTask { await self.fetchWeekWorkouts() }
        }
        await fetchWeeklySummary()
    }
    
    func getWorkout(by id: String) -> Workout? {
        if let workout = todayWorkout, workout.id == id {
            return workout
        }
        return weekWorkouts.first { $0.id == id }
    }
    
    func getOrCreateWorkout(id: String) -> Workout {
        if let workout = getWorkout(by: id) {
            return workout
        }
        // Create a mock workout for the ID
        let types: [WorkoutType] = [.swim, .bike, .run]
        let typeIndex = abs(id.hashValue) % types.count
        var workout = Workout.mock(id: id, type: types[typeIndex], date: Date())
        applyPersistedStatus(to: &workout)
        return workout
    }
    
    // MARK: - Workout Actions
    
    func markWorkoutCompleted(
        id: String,
        duration: Int? = nil,
        distance: Int? = nil,
        avgHeartRate: Int? = nil,
        calories: Int? = nil,
        rating: String? = nil,
        rpe: Int? = nil
    ) async {
        // Update local state immediately for responsiveness
        updateLocalWorkoutStatus(id: id, status: .completed)
        
        // Persist to UserDefaults (for dev mode persistence)
        completedWorkoutIds.insert(id)
        skippedWorkoutIds.remove(id)
        
        // Get the workout for HealthKit sync
        let workout = getWorkout(by: id) ?? getOrCreateWorkout(id: id)
        
        // Sync to HealthKit
        do {
            try await HealthKitService.shared.syncCompletedWorkout(
                workout: workout,
                actualDuration: duration ?? workout.structure.totalDuration,
                actualDistance: distance,
                avgHeartRate: avgHeartRate,
                calories: calories
            )
            print("✅ Workout synced to HealthKit")
        } catch {
            print("⚠️ Failed to sync to HealthKit: \(error)")
        }
        
        // If not in dev mode, also call the API
        if !AuthService.shared.isDevMode {
            do {
                // Complete the workout
                let activityLog = try await apiService.completeWorkout(
                    workoutId: id,
                    duration: duration ?? 0
                )
                
                lastActivityLogId = activityLog.id
                
                // Submit feedback if provided
                if let rating = rating {
                    _ = try await apiService.submitFeedback(
                        activityLogId: activityLog.id,
                        rating: rating,
                        rpe: rpe
                    )
                }
                
                print("Workout \(id) marked as completed in Supabase")
            } catch {
                print("Failed to sync workout completion to server: \(error)")
                // Local state is already updated, will sync later
            }
        } else {
            print("Workout \(id) marked as completed locally (dev mode). Rating: \(rating ?? "none"), RPE: \(String(describing: rpe))")
        }
        
        // Recalculate weekly summary
        await fetchWeeklySummary()
    }
    
    func markWorkoutSkipped(id: String) async {
        // Update local state immediately
        updateLocalWorkoutStatus(id: id, status: .skipped)
        
        // Persist to UserDefaults
        skippedWorkoutIds.insert(id)
        completedWorkoutIds.remove(id)
        
        // If not in dev mode, also call the API
        if !AuthService.shared.isDevMode {
            do {
                try await apiService.skipWorkout(workoutId: id)
                print("Workout \(id) marked as skipped in Supabase")
            } catch {
                print("Failed to sync workout skip to server: \(error)")
            }
        } else {
            print("Workout \(id) marked as skipped locally (dev mode)")
        }
        
        await fetchWeeklySummary()
    }
    
    private func updateLocalWorkoutStatus(id: String, status: WorkoutStatus) {
        // Update today's workout if it matches
        if var workout = todayWorkout, workout.id == id {
            workout.status = status
            todayWorkout = workout
        }
        
        // Update in week workouts
        if let index = weekWorkouts.firstIndex(where: { $0.id == id }) {
            weekWorkouts[index].status = status
        }
    }
    
    // MARK: - Clear Data (for sign out)
    
    func clearAllData() {
        todayWorkout = nil
        weekWorkouts = []
        weeklySummary = nil
        lastActivityLogId = nil
        completedWorkoutIds = []
        skippedWorkoutIds = []
    }
}

struct WeeklySummary {
    let plannedDuration: Int
    let actualDuration: Int
    let completedWorkouts: Int
    let totalWorkouts: Int
    
    var completionRate: Double {
        guard totalWorkouts > 0 else { return 0 }
        return Double(completedWorkouts) / Double(totalWorkouts)
    }
    
    var durationRate: Double {
        guard plannedDuration > 0 else { return 0 }
        return Double(actualDuration) / Double(plannedDuration)
    }
    
    func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
