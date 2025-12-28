import Foundation

struct Race: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var date: Date
    var location: String
    var distanceType: Constants.RaceDistance
    var swimDistanceMeters: Int
    var bikeDistanceMeters: Int
    var runDistanceMeters: Int
    var websiteUrl: String?
    var isCustom: Bool
    var isOfficial: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case date
        case location
        case distanceType = "distance_type"
        case swimDistanceMeters = "swim_distance_meters"
        case bikeDistanceMeters = "bike_distance_meters"
        case runDistanceMeters = "run_distance_meters"
        case websiteUrl = "website_url"
        case isCustom = "is_custom"
        case isOfficial = "is_official"
    }
    
    var daysUntil: Int {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        return max(0, days)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    var swimKm: Double {
        Double(swimDistanceMeters) / 1000
    }
    
    var bikeKm: Double {
        Double(bikeDistanceMeters) / 1000
    }
    
    var runKm: Double {
        Double(runDistanceMeters) / 1000
    }
}

// MARK: - Mock Data
extension Race {
    static let mockRaces: [Race] = [
        Race(
            id: "mock-race-1",
            name: "IRONMAN 70.3 Austin",
            date: Calendar.current.date(byAdding: .month, value: 4, to: Date())!,
            location: "Austin, TX",
            distanceType: .halfIronman,
            swimDistanceMeters: 1930,
            bikeDistanceMeters: 90000,
            runDistanceMeters: 21100,
            websiteUrl: "https://ironman.com",
            isCustom: false,
            isOfficial: true
        ),
        Race(
            id: "mock-race-2",
            name: "Sprint Triathlon Championship",
            date: Calendar.current.date(byAdding: .month, value: 2, to: Date())!,
            location: "San Diego, CA",
            distanceType: .sprint,
            swimDistanceMeters: 750,
            bikeDistanceMeters: 20000,
            runDistanceMeters: 5000,
            websiteUrl: nil,
            isCustom: false,
            isOfficial: true
        ),
        Race(
            id: "mock-race-3",
            name: "Olympic Distance Tri",
            date: Calendar.current.date(byAdding: .month, value: 6, to: Date())!,
            location: "Chicago, IL",
            distanceType: .olympic,
            swimDistanceMeters: 1500,
            bikeDistanceMeters: 40000,
            runDistanceMeters: 10000,
            websiteUrl: nil,
            isCustom: false,
            isOfficial: true
        )
    ]
}

struct TrainingPlan: Codable, Identifiable {
    let id: String
    let userId: String
    var raceId: String?
    var status: PlanStatus
    var startDate: Date
    var endDate: Date?
    var currentWeek: Int
    var totalWeeks: Int
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case raceId = "race_id"
        case status
        case startDate = "start_date"
        case endDate = "end_date"
        case currentWeek = "current_week"
        case totalWeeks = "total_weeks"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum PlanStatus: String, Codable {
    case active = "active"
    case completed = "completed"
    case archived = "archived"
}

