import UIKit
import CoreHaptics

class HapticService {
    static let shared = HapticService()
    
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false
    
    private init() {
        setupHaptics()
    }
    
    private func setupHaptics() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        
        guard supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            engine?.stoppedHandler = { [weak self] reason in
                print("Haptic engine stopped: \(reason)")
                self?.restartEngine()
            }
            engine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                self?.restartEngine()
            }
            try engine?.start()
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }
    
    private func restartEngine() {
        guard supportsHaptics else { return }
        
        do {
            try engine?.start()
        } catch {
            print("Failed to restart haptic engine: \(error)")
        }
    }
    
    // MARK: - Simple Haptics
    
    func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    // MARK: - Workout Haptics
    
    func intervalCountdown(secondsRemaining: Int) {
        switch secondsRemaining {
        case 3, 2, 1:
            medium()
        case 0:
            success()
        default:
            break
        }
    }
    
    func workoutComplete() {
        guard supportsHaptics, let engine = engine else {
            success()
            return
        }
        
        do {
            let pattern = try celebrationPattern()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            success()
        }
    }
    
    private func celebrationPattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        // Create a celebration pattern with multiple bursts
        for i in 0..<3 {
            let time = TimeInterval(i) * 0.2
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: time
            )
            events.append(event)
        }
        
        return try CHHapticPattern(events: events, parameters: [])
    }
}

