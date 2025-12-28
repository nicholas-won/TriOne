import Foundation

/// Calculates personalized workout targets from zones and user biometrics
struct PersonalizedWorkoutCalculator {
    let biometrics: Biometrics
    let workoutType: WorkoutType
    
    // MARK: - Zone Calculations
    
    /// Calculate wattage range for a zone (Bike)
    func calculateWattageRange(for zone: Int) -> (min: Int, max: Int)? {
        guard workoutType == .bike,
              let ftp = biometrics.functionalThresholdPower else {
            return nil
        }
        
        switch zone {
        case 1: // < 55% FTP
            return (0, Int(Double(ftp) * 0.55))
        case 2: // 56-75% FTP
            return (Int(Double(ftp) * 0.56), Int(Double(ftp) * 0.75))
        case 3: // 76-90% FTP
            return (Int(Double(ftp) * 0.76), Int(Double(ftp) * 0.90))
        case 4: // 91-105% FTP
            return (Int(Double(ftp) * 0.91), Int(Double(ftp) * 1.05))
        case 5: // 106-120% FTP (VO2 Max)
            return (Int(Double(ftp) * 1.06), Int(Double(ftp) * 1.20))
        default:
            return nil
        }
    }
    
    /// Calculate pace range for a zone (Run)
    /// Note: "Slower" means adding time (higher seconds per mile)
    func calculatePaceRange(for zone: Int) -> (min: Int, max: Int)? {
        guard workoutType == .run,
              let thresholdPace = biometrics.thresholdRunPace else {
            return nil
        }
        
        // Threshold pace in seconds per mile
        let thresholdSeconds = thresholdPace
        
        switch zone {
        case 1: // +2:00 slower than threshold (120 seconds slower = easier)
            let maxPace = thresholdSeconds + 120 // Slowest (easiest)
            let minPace = thresholdSeconds + 150 // Even slower for recovery
            return (minPace, maxPace)
        case 2: // +1:30 slower than threshold (90 seconds slower)
            let maxPace = thresholdSeconds + 90
            let minPace = thresholdSeconds + 60
            return (minPace, maxPace)
        case 3: // +0:45 slower than threshold (45 seconds slower)
            let maxPace = thresholdSeconds + 45
            let minPace = thresholdSeconds + 20
            return (minPace, maxPace)
        case 4: // Matches threshold pace (±5% tolerance)
            return (Int(Double(thresholdSeconds) * 0.95), Int(Double(thresholdSeconds) * 1.05))
        case 5: // Faster than threshold (VO2 Max)
            return (Int(Double(thresholdSeconds) * 0.85), Int(Double(thresholdSeconds) * 0.95))
        default:
            return nil
        }
    }
    
    /// Calculate pace range for a zone (Swim)
    func calculateSwimPaceRange(for zone: Int) -> (min: Int, max: Int)? {
        guard workoutType == .swim,
              let css = biometrics.criticalSwimSpeed else {
            return nil
        }
        
        // CSS is in seconds per 100m
        switch zone {
        case 1: // Recovery - 15-25% slower than CSS
            return (Int(css * 1.15), Int(css * 1.25))
        case 2: // Endurance - 5-15% slower than CSS
            return (Int(css * 1.05), Int(css * 1.15))
        case 3: // Tempo - 0-5% slower than CSS
            return (Int(css * 1.0), Int(css * 1.05))
        case 4: // Threshold - matches CSS
            return (Int(css * 0.95), Int(css * 1.05))
        case 5: // VO2 Max - faster than CSS
            return (Int(css * 0.85), Int(css * 0.95))
        default:
            return nil
        }
    }
    
    // MARK: - Formatting
    
    /// Format wattage range as string
    func formatWattageRange(for zone: Int) -> String? {
        guard let range = calculateWattageRange(for: zone) else { return nil }
        
        if zone == 1 {
            return "< \(range.max) Watts"
        } else if zone == 4 {
            // For threshold, show specific target
            if let ftp = biometrics.functionalThresholdPower {
                return "\(ftp) Watts"
            }
        }
        
        return "\(range.min) - \(range.max) Watts"
    }
    
    /// Format run pace range as string
    func formatRunPaceRange(for zone: Int) -> String? {
        guard let range = calculatePaceRange(for: zone) else { return nil }
        
        let minPace = formatPace(range.min)
        let maxPace = formatPace(range.max)
        
        if zone == 1 {
            return "< \(maxPace)/mi"
        } else if zone == 4 {
            // For threshold, show specific target
            if let thresholdPace = biometrics.thresholdRunPace {
                return formatPace(thresholdPace) + "/mi"
            }
        }
        
        return "\(minPace) - \(maxPace)/mi"
    }
    
    /// Format swim pace range as string
    func formatSwimPaceRange(for zone: Int) -> String? {
        guard let range = calculateSwimPaceRange(for: zone) else { return nil }
        
        let minPace = formatSwimPace(range.min)
        let maxPace = formatSwimPace(range.max)
        
        if zone == 4 {
            // For threshold, show CSS
            if let css = biometrics.criticalSwimSpeed {
                return formatSwimPace(Int(css)) + "/100m"
            }
        }
        
        return "\(minPace) - \(maxPace)/100m"
    }
    
    /// Get personalized target text for a step
    func getPersonalizedTargetText(for step: WorkoutStep) -> String {
        guard let zone = step.targetZone else {
            return step.targetText
        }
        
        switch workoutType {
        case .bike:
            if let wattage = formatWattageRange(for: zone) {
                return wattage
            }
        case .run:
            if let pace = formatRunPaceRange(for: zone) {
                return pace
            }
        case .swim:
            if let pace = formatSwimPaceRange(for: zone) {
                return pace
            }
        default:
            break
        }
        
        return step.targetText
    }
    
    /// Get personalized coaching instruction for a step
    func getPersonalizedCoaching(for step: WorkoutStep) -> String {
        guard let zone = step.targetZone else {
            return step.description ?? "Maintain steady effort"
        }
        
        switch workoutType {
        case .bike:
            switch zone {
            case 1:
                return "Spin easy to prime legs. Keep it conversational."
            case 2:
                return "Stay aerobic, but focused. You should feel comfortable."
            case 3:
                return "Steady tempo effort. Breathing increases but controlled."
            case 4:
                return "Hold exactly at FTP. This is your sustainable max."
            case 5:
                return "Push above threshold. Short, hard efforts."
            default:
                return step.description ?? "Maintain steady effort"
            }
        case .run:
            switch zone {
            case 1:
                return "Easy recovery pace. Keep legs moving, breathe deeply."
            case 2:
                return "Comfortable endurance pace. Can hold conversation."
            case 3:
                return "Tempo effort. Comfortably hard, few words."
            case 4:
                return "Threshold pace. Hard but sustainable for duration."
            case 5:
                return "VO2 Max effort. Very hard, short intervals."
            default:
                return step.description ?? "Maintain steady effort"
            }
        case .swim:
            switch zone {
            case 1:
                return "Easy recovery. Focus on technique and breathing."
            case 2:
                return "Endurance pace. Maintain good form throughout."
            case 3:
                return "Tempo effort. Strong but controlled."
            case 4:
                return "CSS pace. Your sustainable swimming speed."
            case 5:
                return "Fast intervals. Push above CSS."
            default:
                return step.description ?? "Maintain steady effort"
            }
        default:
            return step.description ?? "Maintain steady effort"
        }
    }
    
    // MARK: - Helper Formatting
    
    private func formatPace(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private func formatSwimPace(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Workout Title Generator

struct WorkoutTitleGenerator {
    static func generateTitle(for structure: WorkoutStructure, type: WorkoutType) -> String {
        // Analyze the workout structure to generate a descriptive title
        let hasIntervals = structure.steps.contains { $0.type == .interval }
        let hasTempo = structure.steps.contains { $0.targetZone == 3 }
        let hasThreshold = structure.steps.contains { $0.targetZone == 4 }
        let isBrick = type == .brick
        
        if isBrick {
            return "Brick Builder"
        }
        
        if hasThreshold && hasIntervals {
            return "Threshold Intervals"
        } else if hasThreshold {
            return "Threshold Hold"
        } else if hasTempo && hasIntervals {
            return "Tempo Brick Builder"
        } else if hasTempo {
            return "Tempo Endurance"
        } else if hasIntervals {
            return "Interval Power"
        } else {
            return "Endurance Session"
        }
    }
}

// MARK: - Workout "Why" Generator

struct WorkoutWhyGenerator {
    static func generateWhy(for structure: WorkoutStructure, type: WorkoutType) -> String {
        let hasIntervals = structure.steps.contains { $0.type == .interval }
        let hasThreshold = structure.steps.contains { $0.targetZone == 4 }
        let hasTempo = structure.steps.contains { $0.targetZone == 3 }
        
        if hasThreshold && hasIntervals {
            return "This session builds your ability to clear lactate at high speeds. We are pushing your FTP ceiling up by alternating hard efforts with incomplete rest."
        } else if hasThreshold {
            return "Sustained threshold work increases your ability to maintain high intensity for longer periods, building both aerobic and anaerobic capacity."
        } else if hasTempo {
            return "Tempo efforts improve your efficiency at race pace, teaching your body to clear lactate while maintaining intensity."
        } else if hasIntervals {
            return "Interval training develops your VO2 max and improves your ability to recover quickly between hard efforts."
        } else {
            return "This endurance session builds your aerobic base, improving fat utilization and cardiovascular efficiency."
        }
    }
}

