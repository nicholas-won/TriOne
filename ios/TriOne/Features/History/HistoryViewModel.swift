import SwiftUI
import Combine

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var timeRange: HistoryView.TimeRange = .month {
        didSet { applyFilters() }
    }
    @Published var typeFilter: WorkoutType? = nil {
        didSet { applyFilters() }
    }
    
    var filteredActivities: [Activity] {
        var result = activities
        
        // Apply time range filter
        let now = Date()
        let calendar = Calendar.current
        
        switch timeRange {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            result = result.filter { $0.completedAt >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            result = result.filter { $0.completedAt >= monthAgo }
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            result = result.filter { $0.completedAt >= yearAgo }
        case .all:
            break
        }
        
        // Apply type filter
        if let typeFilter = typeFilter {
            result = result.filter { $0.workoutType == typeFilter }
        }
        
        return result.sorted { $0.completedAt > $1.completedAt }
    }
    
    var groupedActivities: [ActivityGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredActivities) { activity in
            calendar.startOfDay(for: activity.completedAt)
        }
        
        return grouped.map { date, activities in
            ActivityGroup(date: date, activities: activities.sorted { $0.completedAt > $1.completedAt })
        }
        .sorted { $0.date > $1.date }
    }
    
    // MARK: - Summary Stats
    
    var totalWorkouts: Int {
        filteredActivities.count
    }
    
    var totalDurationSeconds: Int {
        filteredActivities.reduce(0) { $0 + $1.durationSeconds }
    }
    
    var formattedTotalDuration: String {
        let hours = totalDurationSeconds / 3600
        let minutes = (totalDurationSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    var totalDistanceMeters: Int {
        filteredActivities.compactMap { $0.distanceMeters }.reduce(0, +)
    }
    
    var formattedTotalDistance: String {
        let miles = Double(totalDistanceMeters) / 1609.34
        if miles >= 100 {
            return String(format: "%.0f mi", miles)
        } else if miles >= 10 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.2f mi", miles)
        }
    }
    
    // MARK: - Load Data
    
    func loadActivities() async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        if AuthService.shared.isDevMode {
            // Generate mock activities
            activities = Activity.mockHistory()
            return
        }
        
        // TODO: Load from API
        do {
            // let response = try await APIService.shared.getActivityHistory()
            // activities = response.map { Activity.from(response: $0) }
            activities = Activity.mockHistory() // Fallback to mock for now
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func applyFilters() {
        objectWillChange.send()
    }
}

// MARK: - Activity Model

struct Activity: Identifiable {
    let id: String
    let workoutId: String?
    let workoutType: WorkoutType
    let title: String
    let completedAt: Date
    let durationSeconds: Int
    let distanceMeters: Int?
    let avgHeartRate: Int?
    let rating: String?
    let rpe: Int?
    
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
    
    var formattedTime: String {
        completedAt.formatted(date: .omitted, time: .shortened)
    }
}

struct ActivityGroup: Identifiable {
    let date: Date
    let activities: [Activity]
    
    var id: Date { date }
    
    var formattedDate: String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            return date.formatted(.dateTime.weekday(.wide))
        } else {
            return date.formatted(.dateTime.month().day())
        }
    }
}

// MARK: - Mock Data

extension Activity {
    static func mockHistory() -> [Activity] {
        let calendar = Calendar.current
        let now = Date()
        var activities: [Activity] = []
        
        let types: [WorkoutType] = [.swim, .bike, .run, .strength, .brick]
        let titles: [WorkoutType: [String]] = [
            .swim: ["Morning Swim", "Endurance Swim", "Technique Focus", "CSS Test"],
            .bike: ["Easy Ride", "Tempo Ride", "Hill Repeats", "FTP Intervals"],
            .run: ["Easy Run", "Tempo Run", "Track Intervals", "Long Run"],
            .strength: ["Core Strength", "Full Body", "Upper Body"],
            .brick: ["Bike to Run", "Sprint Brick"]
        ]
        
        // Generate activities for the past 30 days
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            
            // 70% chance of having a workout each day
            if Double.random(in: 0...1) > 0.3 {
                let type = types.randomElement()!
                let title = titles[type]?.randomElement() ?? "Workout"
                
                // Random time between 6am and 8pm
                let hour = Int.random(in: 6...20)
                let minute = Int.random(in: 0...59)
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = hour
                components.minute = minute
                let completedAt = calendar.date(from: components) ?? date
                
                let activity = Activity(
                    id: UUID().uuidString,
                    workoutId: "mock-workout-\(dayOffset)",
                    workoutType: type,
                    title: title,
                    completedAt: completedAt,
                    durationSeconds: Int.random(in: 1800...5400),
                    distanceMeters: type == .strength ? nil : Int.random(in: 3000...25000),
                    avgHeartRate: Int.random(in: 120...165),
                    rating: ["easier", "same", "harder"].randomElement(),
                    rpe: Int.random(in: 4...8)
                )
                
                activities.append(activity)
            }
        }
        
        return activities.sorted { $0.completedAt > $1.completedAt }
    }
}

