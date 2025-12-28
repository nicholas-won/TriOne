import Foundation

/**
 * Biometrics Calculator
 * 
 * iOS implementation of the algorithm's mathematical models.
 * Mirrors the backend calculations for consistency.
 */
enum BiometricsCalculator {
    
    // MARK: - Age & Max Heart Rate
    
    /// Calculate age from date of birth
    static func calculateAge(from dob: Date) -> Int {
        Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
    }
    
    /// Calculate Max Heart Rate using the standard formula: Max_HR = 220 - Age
    static func calculateMaxHR(age: Int) -> Int {
        220 - age
    }
    
    /// Get Max HR - use provided value if available, otherwise calculate
    static func getMaxHR(userMaxHR: Int?, dob: Date) -> Int {
        if let maxHR = userMaxHR, maxHR > 0 {
            return maxHR
        }
        return calculateMaxHR(age: calculateAge(from: dob))
    }
    
    // MARK: - Swimming - Critical Swim Speed (CSS)
    
    /// Calculate CSS from 400m Time Trial
    /// Formula: CSS (sec/100m) = (Time_400m / 4) + 3.0
    static func calculateCSS(from time400m: Int) -> Double {
        (Double(time400m) / 4.0) + 3.0
    }
    
    /// Calculate target pace for swim workout
    static func calculateSwimTargetPace(css: Double, coefficient: Double) -> Int {
        Int((css * coefficient).rounded())
    }
    
    /// Format swim pace as min:sec/100m
    static func formatSwimPace(_ secondsPer100m: Double) -> String {
        let totalSeconds = Int(secondsPer100m)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d/100m", minutes, seconds)
    }
    
    // MARK: - Running - Threshold Pace
    
    /// Calculate Threshold Pace from 1 Mile Time Trial
    /// Formula: TP (sec/mile) = Time_1mile × 1.15
    static func calculateThresholdPace(from time1Mile: Int) -> Int {
        Int((Double(time1Mile) * 1.15).rounded())
    }
    
    /// Calculate target pace for run workout
    static func calculateRunTargetPace(thresholdPace: Int, coefficient: Double) -> Int {
        Int((Double(thresholdPace) * coefficient).rounded())
    }
    
    /// Format run pace as min:sec/mi
    static func formatRunPace(_ secondsPerMile: Int) -> String {
        let minutes = secondsPerMile / 60
        let seconds = secondsPerMile % 60
        return String(format: "%d:%02d/mi", minutes, seconds)
    }
    
    // MARK: - Cycling - FTP
    
    /// Calculate FTP from 20-minute Power Test
    /// Formula: FTP = Average_20min_Power × 0.95
    static func calculateFTP(from avgPower20min: Int) -> Int {
        Int((Double(avgPower20min) * 0.95).rounded())
    }
    
    /// Calculate target power for bike workout
    static func calculateBikeTargetPower(ftp: Int, coefficient: Double) -> Int {
        Int((Double(ftp) * coefficient).rounded())
    }
    
    /// Calculate Power-to-Weight ratio
    static func calculateWattsPerKg(ftp: Int, weightKg: Double) -> Double {
        guard weightKg > 0 else { return 0 }
        return Double(ftp) / weightKg
    }
    
    // MARK: - Heart Rate Zones
    
    struct HeartRateZones {
        let zone1: (min: Int, max: Int, name: String)
        let zone2: (min: Int, max: Int, name: String)
        let zone3: (min: Int, max: Int, name: String)
        let zone4: (min: Int, max: Int, name: String)
        let zone5: (min: Int, max: Int, name: String)
        let method: HRCalculationMethod
        
        subscript(zone: Int) -> (min: Int, max: Int, name: String)? {
            switch zone {
            case 1: return zone1
            case 2: return zone2
            case 3: return zone3
            case 4: return zone4
            case 5: return zone5
            default: return nil
            }
        }
        
        var allZones: [(zone: Int, min: Int, max: Int, name: String)] {
            [
                (1, zone1.min, zone1.max, zone1.name),
                (2, zone2.min, zone2.max, zone2.name),
                (3, zone3.min, zone3.max, zone3.name),
                (4, zone4.min, zone4.max, zone4.name),
                (5, zone5.min, zone5.max, zone5.name)
            ]
        }
    }
    
    /// Calculate Standard HR Zones (% of Max HR)
    static func calculateStandardHRZones(maxHR: Int) -> HeartRateZones {
        HeartRateZones(
            zone1: (min: Int(Double(maxHR) * 0.50), max: Int(Double(maxHR) * 0.60), name: "Recovery"),
            zone2: (min: Int(Double(maxHR) * 0.60), max: Int(Double(maxHR) * 0.75), name: "Endurance"),
            zone3: (min: Int(Double(maxHR) * 0.75), max: Int(Double(maxHR) * 0.85), name: "Tempo"),
            zone4: (min: Int(Double(maxHR) * 0.85), max: Int(Double(maxHR) * 0.95), name: "Threshold"),
            zone5: (min: Int(Double(maxHR) * 0.95), max: maxHR, name: "VO2 Max"),
            method: .standard
        )
    }
    
    /// Calculate Karvonen HR Zones (using Heart Rate Reserve)
    /// Formula: Target_HR = ((Max_HR - Resting_HR) × %) + Resting_HR
    static func calculateKarvonenHRZones(maxHR: Int, restingHR: Int) -> HeartRateZones {
        let hrr = maxHR - restingHR
        
        func karvonen(_ pct: Double) -> Int {
            Int((Double(hrr) * pct) + Double(restingHR))
        }
        
        return HeartRateZones(
            zone1: (min: karvonen(0.50), max: karvonen(0.60), name: "Recovery"),
            zone2: (min: karvonen(0.60), max: karvonen(0.75), name: "Endurance"),
            zone3: (min: karvonen(0.75), max: karvonen(0.85), name: "Tempo"),
            zone4: (min: karvonen(0.85), max: karvonen(0.95), name: "Threshold"),
            zone5: (min: karvonen(0.95), max: maxHR, name: "VO2 Max"),
            method: .karvonen
        )
    }
    
    /// Get HR Zones using the appropriate method
    static func getHeartRateZones(maxHR: Int, restingHR: Int?) -> HeartRateZones {
        if let rhr = restingHR, rhr > 0 {
            return calculateKarvonenHRZones(maxHR: maxHR, restingHR: rhr)
        }
        return calculateStandardHRZones(maxHR: maxHR)
    }
    
    /// Get target HR for a zone (midpoint)
    static func getTargetHR(for zone: Int, zones: HeartRateZones) -> Int {
        guard let zoneData = zones[zone] else { return 0 }
        return (zoneData.min + zoneData.max) / 2
    }
    
    // MARK: - Intensity Scalar
    
    /// Apply intensity scalar to a target value
    /// Core Formula: Target = Template_Coefficient × User_Scalar × Intensity_Scalar
    static func applyIntensityScalar(
        templateCoefficient: Double,
        userScalar: Double,
        intensityScalar: Double = 1.0
    ) -> Int {
        Int((templateCoefficient * userScalar * intensityScalar).rounded())
    }
    
    // MARK: - Calorie Estimation
    
    /// Estimate calories burned during exercise
    static func estimateCalories(
        workoutType: String,
        durationMinutes: Int,
        weightKg: Double,
        intensity: Int = 3
    ) -> Int {
        let baseMET: [String: Double] = [
            "swim": 8.0,
            "bike": 7.0,
            "run": 9.0,
            "strength": 5.0,
            "brick": 8.5
        ]
        
        let intensityMultiplier = 0.8 + (Double(intensity) * 0.1)
        let met = (baseMET[workoutType] ?? 6.0) * intensityMultiplier
        let durationHours = Double(durationMinutes) / 60.0
        
        return Int((met * weightKg * durationHours).rounded())
    }
}

