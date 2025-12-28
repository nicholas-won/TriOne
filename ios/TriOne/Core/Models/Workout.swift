import Foundation
import SwiftUI

struct Workout: Codable, Identifiable, Equatable {
    let id: String
    let trainingPlanId: String
    var scheduledDate: Date
    var workoutType: WorkoutType
    var status: WorkoutStatus
    var structure: WorkoutStructure
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case trainingPlanId = "training_plan_id"
        case scheduledDate = "scheduled_date"
        case workoutType = "workout_type"
        case status
        case structure = "calculated_structure"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var color: Color {
        workoutType.color
    }
    
    var icon: String {
        workoutType.icon
    }
}

enum WorkoutType: String, Codable, CaseIterable {
    case swim = "swim"
    case bike = "bike"
    case run = "run"
    case strength = "strength"
    case brick = "brick"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: Color {
        switch self {
        case .swim: return Theme.swim
        case .bike: return Theme.bike
        case .run: return Theme.run
        case .strength: return Theme.strength
        case .brick: return Theme.brick
        }
    }
    
    var icon: String {
        switch self {
        case .swim: return "drop.fill"
        case .bike: return "bicycle"
        case .run: return "figure.run"
        case .strength: return "dumbbell.fill"
        case .brick: return "bolt.fill"
        }
    }
}

enum WorkoutStatus: String, Codable {
    case scheduled = "scheduled"
    case completed = "completed"
    case missed = "missed"
    case skipped = "skipped"
}

struct WorkoutStructure: Codable, Equatable {
    let title: String
    let description: String
    let totalDuration: Int // seconds
    let steps: [WorkoutStep]
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case totalDuration = "total_duration"
        case steps
    }
    
    var formattedDuration: String {
        let hours = totalDuration / 3600
        let minutes = (totalDuration % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct WorkoutStep: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let type: StepType
    let duration: Int // seconds
    var description: String?
    var targetZone: Int?
    var targetWattage: Int?
    var targetPace: Int? // seconds per mile
    var targetHeartRate: Int?
    
    enum CodingKeys: String, CodingKey {
        case type
        case duration
        case description
        case targetZone = "target_zone"
        case targetWattage = "target_wattage"
        case targetPace = "target_pace"
        case targetHeartRate = "target_heart_rate"
    }
    
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var targetText: String {
        var parts: [String] = []
        if let wattage = targetWattage { parts.append("\(wattage)W") }
        if let pace = targetPace { 
            let mins = pace / 60
            let secs = pace % 60
            parts.append(String(format: "%d:%02d/mi", mins, secs))
        }
        if let hr = targetHeartRate { parts.append("\(hr) bpm") }
        if let zone = targetZone { parts.append("Zone \(zone)") }
        return parts.isEmpty ? "Easy effort" : parts.joined(separator: " • ")
    }
    
    var isIntense: Bool {
        type == .interval || type == .main
    }
}

enum StepType: String, Codable {
    case warmup = "warmup"
    case main = "main"
    case interval = "interval"
    case rest = "rest"
    case cooldown = "cooldown"
    
    var displayName: String {
        switch self {
        case .warmup: return "Warm Up"
        case .main: return "Main Set"
        case .interval: return "Interval"
        case .rest: return "Rest"
        case .cooldown: return "Cool Down"
        }
    }
}

// MARK: - API Response Conversion
extension Workout {
    static func from(response: WorkoutResponse) -> Workout {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let scheduledDate = dateFormatter.date(from: response.scheduledDate) ?? Date()
        
        let workoutType = WorkoutType(rawValue: response.workoutType) ?? .run
        let status: WorkoutStatus
        switch response.status {
        case "completed": status = .completed
        case "missed": status = .missed
        case "skipped": status = .skipped
        default: status = .scheduled
        }
        
        let steps = response.calculatedStructure.steps.map { stepResponse -> WorkoutStep in
            let stepType: StepType
            switch stepResponse.type {
            case "warmup": stepType = .warmup
            case "main": stepType = .main
            case "interval": stepType = .interval
            case "rest": stepType = .rest
            case "cooldown": stepType = .cooldown
            default: stepType = .main
            }
            
            return WorkoutStep(
                type: stepType,
                duration: stepResponse.duration,
                description: stepResponse.description,
                targetZone: stepResponse.targetZone,
                targetWattage: stepResponse.targetPower,
                targetPace: nil, // Would need to parse targetPace string
                targetHeartRate: nil
            )
        }
        
        return Workout(
            id: response.id,
            trainingPlanId: response.planId,
            scheduledDate: scheduledDate,
            workoutType: workoutType,
            status: status,
            structure: WorkoutStructure(
                title: response.calculatedStructure.title,
                description: response.calculatedStructure.description,
                totalDuration: response.calculatedStructure.totalDuration,
                steps: steps
            ),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

// MARK: - Mock Data
extension Workout {
    static func mock(
        id: String = UUID().uuidString,
        type: WorkoutType = .run,
        date: Date = Date(),
        status: WorkoutStatus = .scheduled
    ) -> Workout {
        let titles: [WorkoutType: [String]] = [
            .swim: ["Endurance Swim", "Technique Focus", "Interval Swim", "CSS Test"],
            .bike: ["Easy Ride", "Tempo Ride", "Hill Repeats", "FTP Intervals"],
            .run: ["Easy Run", "Tempo Run", "Track Intervals", "Long Run"],
            .strength: ["Core Strength", "Full Body", "Upper Body", "Lower Body"],
            .brick: ["Bike to Run", "Sprint Brick", "Race Simulation"]
        ]
        
        let descriptions: [WorkoutType: String] = [
            .swim: "Focus on maintaining good form and building aerobic endurance in the water.",
            .bike: "Build your cycling fitness with this structured session targeting power and endurance.",
            .run: "Develop your running economy and cardiovascular capacity with this workout.",
            .strength: "Build functional strength to support your triathlon training.",
            .brick: "Practice the bike-to-run transition for race day readiness."
        ]
        
        let title = titles[type]?.randomElement() ?? "Workout"
        let totalDuration = Int.random(in: 1800...5400) // 30-90 min
        
        let steps: [WorkoutStep] = [
            WorkoutStep(type: .warmup, duration: 600, description: "Easy effort to warm up muscles", targetZone: 2),
            WorkoutStep(type: .main, duration: totalDuration - 1500, description: "Steady effort at moderate intensity", targetZone: 3),
            WorkoutStep(type: .interval, duration: 300, description: "Push harder for this interval", targetZone: 4),
            WorkoutStep(type: .rest, duration: 120, description: "Easy recovery", targetZone: 1),
            WorkoutStep(type: .interval, duration: 300, description: "Second hard interval", targetZone: 4),
            WorkoutStep(type: .cooldown, duration: 480, description: "Easy cooldown", targetZone: 1)
        ]
        
        return Workout(
            id: id,
            trainingPlanId: "mock-plan-1",
            scheduledDate: date,
            workoutType: type,
            status: status,
            structure: WorkoutStructure(
                title: title,
                description: descriptions[type] ?? "",
                totalDuration: steps.reduce(0) { $0 + $1.duration },
                steps: steps
            ),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    static func mockWeek() -> [Workout] {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        let schedule: [(day: Int, type: WorkoutType?)] = [
            (0, nil), // Sunday rest
            (1, .swim),
            (2, .bike),
            (3, .run),
            (4, .swim),
            (5, .bike),
            (6, .run)
        ]
        
        return schedule.compactMap { item -> Workout? in
            guard let type = item.type else { return nil }
            let date = calendar.date(byAdding: .day, value: item.day, to: startOfWeek)!
            
            var status: WorkoutStatus = .scheduled
            if date < today && !calendar.isDate(date, inSameDayAs: today) {
                status = Bool.random() ? .completed : (Bool.random() ? .missed : .completed)
            }
            
            return Workout.mock(
                id: "mock-workout-\(item.day)",
                type: type,
                date: date,
                status: status
            )
        }
    }
}

