import HealthKit
import Combine

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false
    @Published var authorizationError: String?
    @Published var autoSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoSyncEnabled, forKey: "healthKitAutoSync")
        }
    }
    
    private init() {
        autoSyncEnabled = UserDefaults.standard.bool(forKey: "healthKitAutoSync")
    }
    
    // Types we want to read
    private var readTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = []
        
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let restingHR = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let swimDistance = HKQuantityType.quantityType(forIdentifier: .distanceSwimming) {
            types.insert(swimDistance)
        }
        if let cyclingDistance = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
            types.insert(cyclingDistance)
        }
        if let vo2Max = HKQuantityType.quantityType(forIdentifier: .vo2Max) {
            types.insert(vo2Max)
        }
        
        types.insert(HKObjectType.workoutType())
        
        return types
    }
    
    // Types we want to write
    private var writeTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = []
        
        types.insert(HKObjectType.workoutType())
        
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let swimDistance = HKQuantityType.quantityType(forIdentifier: .distanceSwimming) {
            types.insert(swimDistance)
        }
        if let cyclingDistance = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
            types.insert(cyclingDistance)
        }
        
        return types
    }
    
    // Check if HealthKit is available
    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        guard isHealthDataAvailable else {
            authorizationError = "Health data is not available on this device"
            return false
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            return true
        } catch {
            authorizationError = error.localizedDescription
            isAuthorized = false
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        // Check if we can write workouts (indicates user granted permission)
        let workoutType = HKObjectType.workoutType()
        let status = healthStore.authorizationStatus(for: workoutType)
        isAuthorized = status == .sharingAuthorized
    }
    
    // MARK: - Auto-Sync After Workout Completion
    
    /// Saves a completed workout to HealthKit
    func syncCompletedWorkout(
        workout: Workout,
        actualDuration: Int, // seconds
        actualDistance: Int?, // meters
        avgHeartRate: Int?,
        calories: Int?
    ) async throws {
        guard autoSyncEnabled && isAuthorized else { return }
        
        let activityType = Self.healthKitActivityType(for: workout.workoutType)
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-Double(actualDuration))
        
        // Create the workout
        var workoutBuilder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: HKWorkoutConfiguration(),
            device: nil
        )
        
        // Set activity type
        var configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        
        workoutBuilder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: nil
        )
        
        try await workoutBuilder.beginCollection(at: startDate)
        
        // Add samples
        var samples: [HKSample] = []
        
        // Distance
        if let distance = actualDistance, distance > 0 {
            let distanceType = distanceQuantityType(for: workout.workoutType)
            if let type = distanceType {
                let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: Double(distance))
                let distanceSample = HKQuantitySample(
                    type: type,
                    quantity: distanceQuantity,
                    start: startDate,
                    end: endDate
                )
                samples.append(distanceSample)
            }
        }
        
        // Energy
        if let calories = calories, calories > 0,
           let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories))
            let energySample = HKQuantitySample(
                type: energyType,
                quantity: energyQuantity,
                start: startDate,
                end: endDate
            )
            samples.append(energySample)
        }
        
        // Heart rate (if available)
        if let hr = avgHeartRate, hr > 0,
           let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            let hrQuantity = HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: Double(hr))
            let hrSample = HKQuantitySample(
                type: hrType,
                quantity: hrQuantity,
                start: startDate,
                end: endDate
            )
            samples.append(hrSample)
        }
        
        if !samples.isEmpty {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                workoutBuilder.add(samples) { _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
        
        try await workoutBuilder.endCollection(at: endDate)
        
        // Finish and save
        let finishedWorkout = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout?, Error>) in
            workoutBuilder.finishWorkout { workout, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: workout)
                }
            }
        }
        
        print("✅ Workout synced to HealthKit: \(finishedWorkout?.uuid.uuidString ?? "unknown")")
    }
    
    // MARK: - Reading Data
    
    func fetchRestingHeartRate() async -> Int? {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor],
                resultsHandler: { _, samples, _ in
                    guard let sample = samples?.first as? HKQuantitySample else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    continuation.resume(returning: Int(bpm))
                }
            )
            
            healthStore.execute(query)
        }
    }
    
    func fetchVO2Max() async -> Double? {
        guard let vo2Type = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
            return nil
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2Type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor],
                resultsHandler: { _, samples, _ in
                    guard let sample = samples?.first as? HKQuantitySample else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let vo2 = sample.quantity.doubleValue(for: HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute())))
                    continuation.resume(returning: vo2)
                }
            )
            
            healthStore.execute(query)
        }
    }
    
    // Fetch recent workouts
    func fetchRecentWorkouts(limit: Int = 10) async -> [HKWorkout] {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: nil,
                limit: limit,
                sortDescriptors: [sortDescriptor],
                resultsHandler: { _, samples, _ in
                    let workouts = samples as? [HKWorkout] ?? []
                    continuation.resume(returning: workouts)
                }
            )
            
            healthStore.execute(query)
        }
    }
    
    // Fetch workout statistics for a date range
    func fetchWorkoutStats(from startDate: Date, to endDate: Date) async -> (count: Int, duration: TimeInterval, distance: Double) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil,
                resultsHandler: { _, samples, _ in
                    let workouts = samples as? [HKWorkout] ?? []
                    let count = workouts.count
                    let duration = workouts.reduce(0) { $0 + $1.duration }
                    let distance = workouts.compactMap { $0.totalDistance?.doubleValue(for: .meter()) }.reduce(0, +)
                    
                    continuation.resume(returning: (count, duration, distance))
                }
            )
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Legacy Save Method
    
    func saveWorkout(
        type: HKWorkoutActivityType,
        start: Date,
        end: Date,
        energyBurned: Double? = nil,
        distance: Double? = nil
    ) async throws {
        var configuration = HKWorkoutConfiguration()
        configuration.activityType = type
        
        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: nil
        )
        
        try await builder.beginCollection(at: start)
        
        var samples: [HKSample] = []
        
        // Add energy burned sample
        if let energy = energyBurned, energy > 0,
           let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: energy)
            let energySample = HKQuantitySample(
                type: energyType,
                quantity: energyQuantity,
                start: start,
                end: end
            )
            samples.append(energySample)
        }
        
        // Add distance sample
        if let dist = distance, dist > 0 {
            let distanceType: HKQuantityType?
            switch type {
            case .swimming:
                distanceType = HKQuantityType.quantityType(forIdentifier: .distanceSwimming)
            case .cycling:
                distanceType = HKQuantityType.quantityType(forIdentifier: .distanceCycling)
            default:
                distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
            }
            
            if let distType = distanceType {
                let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: dist)
                let distanceSample = HKQuantitySample(
                    type: distType,
                    quantity: distanceQuantity,
                    start: start,
                    end: end
                )
                samples.append(distanceSample)
            }
        }
        
        if !samples.isEmpty {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.add(samples) { _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
        
        try await builder.endCollection(at: end)
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout?, Error>) in
            builder.finishWorkout { workout, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: workout)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func distanceQuantityType(for workoutType: WorkoutType) -> HKQuantityType? {
        switch workoutType {
        case .swim:
            return HKQuantityType.quantityType(forIdentifier: .distanceSwimming)
        case .bike:
            return HKQuantityType.quantityType(forIdentifier: .distanceCycling)
        case .run:
            return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .strength, .brick:
            return nil
        }
    }
    
    // Map workout types
    static func healthKitActivityType(for workoutType: WorkoutType) -> HKWorkoutActivityType {
        switch workoutType {
        case .swim: return .swimming
        case .bike: return .cycling
        case .run: return .running
        case .strength: return .functionalStrengthTraining
        case .brick: return .mixedCardio
        }
    }
}
