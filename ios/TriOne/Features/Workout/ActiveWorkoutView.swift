import SwiftUI
import CoreLocation

struct ActiveWorkoutView: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    
    @State private var currentStepIndex = 0
    @State private var timeRemaining = 0
    @State private var totalElapsed = 0
    @State private var isPaused = false
    @State private var isComplete = false
    @State private var timer: Timer?
    @State private var showEndWorkoutSheet = false
    @State private var showFeedbackSheet = false
    @State private var showCompletionCelebration = false
    
    // Personalized calculator
    private var calculator: PersonalizedWorkoutCalculator? {
        guard let biometrics = authService.currentUser?.biometrics else { return nil }
        return PersonalizedWorkoutCalculator(
            biometrics: biometrics,
            workoutType: workout.workoutType
        )
    }
    
    private var currentStep: WorkoutStep? {
        guard currentStepIndex < workout.structure.steps.count else { return nil }
        return workout.structure.steps[currentStepIndex]
    }
    
    private var nextStep: WorkoutStep? {
        guard currentStepIndex + 1 < workout.structure.steps.count else { return nil }
        return workout.structure.steps[currentStepIndex + 1]
    }
    
    private var progressPercent: Double {
        guard workout.structure.steps.count > 0 else { return 0 }
        return Double(currentStepIndex) / Double(workout.structure.steps.count)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if showCompletionCelebration {
                completionView
            } else {
                workoutView
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startWorkout()
        }
        .onDisappear {
            stopTimer()
        }
        .sheet(isPresented: $showEndWorkoutSheet) {
            EndWorkoutSheet(
                workout: workout,
                totalElapsed: totalElapsed,
                stepsCompleted: currentStepIndex,
                totalSteps: workout.structure.steps.count,
                onMarkComplete: {
                    markWorkoutComplete()
                },
                onDiscard: {
                    discardWorkout()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFeedbackSheet) {
            WorkoutFeedbackSheet(
                workout: workout,
                totalDuration: totalElapsed,
                onSubmit: { rating, rpe in
                    submitFeedback(rating: rating, rpe: rpe)
                },
                onSkip: {
                    showFeedbackSheet = false
                    showCompletionCelebration = true
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }
        .onChange(of: isComplete) { _, complete in
            if complete {
                HapticService.shared.workoutComplete()
                // Show feedback sheet first, then celebration
                showFeedbackSheet = true
            }
        }
    }
    
    // MARK: - Workout View
    
    private var workoutView: some View {
        VStack(spacing: 0) {
            headerSection
            Spacer()
            mainDisplaySection
            Spacer()
            nextUpSection
                .padding(.bottom, 32)
            controlsSection
        }
    }
    
    private var headerSection: some View {
        HStack {
            // End Workout Button
            Button {
                isPaused = true
                showEndWorkoutSheet = true
                HapticService.shared.medium()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(8)
            }
            
            Spacer()
            
            // Title & Progress
            VStack(spacing: 4) {
                Text(workout.structure.title)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(Theme.primary)
                            .frame(width: geo.size.width * progressPercent, height: 4)
                    }
                }
                .frame(height: 4)
                .frame(width: 100)
            }
            
            Spacer()
            
            // Skip Button
            Button {
                skipToNextStep()
                HapticService.shared.light()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var mainDisplaySection: some View {
        VStack(spacing: 16) {
            // Current Step Name (Personalized)
            Text(getPersonalizedStepName(for: currentStep) ?? "Complete!")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.6))
            
            // Timer
            Text(formatTime(timeRemaining))
                .font(.system(size: 96, weight: .bold, design: .monospaced))
                .foregroundStyle(timeRemaining <= 3 ? Theme.primary : .white)
            
            // Target (Personalized)
            if let step = currentStep {
                VStack(spacing: 4) {
                    Text(getPersonalizedTargetText(for: step))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    // Coaching instruction
                    if let coaching = getPersonalizedCoaching(for: step) {
                        Text(coaching)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Theme.primary)
                .cornerRadius(24)
            }
            
            // Progress
            Text("Step \(currentStepIndex + 1) of \(workout.structure.steps.count)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 8)
        }
    }
    
    // MARK: - Personalized Helpers
    
    private func getPersonalizedStepName(for step: WorkoutStep?) -> String? {
        guard let step = step else { return nil }
        
        // Use personalized step names if calculator is available
        switch step.type {
        case .warmup:
            return "Warm Up"
        case .main:
            if step.targetZone == 3 {
                return "Tempo Hold"
            } else if step.targetZone == 2 {
                return "Endurance"
            }
            return "Main Set"
        case .interval:
            if step.targetZone == 4 {
                return "Threshold Push"
            } else if step.targetZone == 5 {
                return "VO2 Max"
            }
            return "Interval"
        case .rest:
            return "Active Recovery"
        case .cooldown:
            return "Cool Down"
        }
    }
    
    private func getPersonalizedTargetText(for step: WorkoutStep) -> String {
        if let calculator = calculator {
            return calculator.getPersonalizedTargetText(for: step)
        }
        return step.targetText
    }
    
    private func getPersonalizedCoaching(for step: WorkoutStep) -> String? {
        if let calculator = calculator {
            let coaching = calculator.getPersonalizedCoaching(for: step)
            // Only show coaching if it's different from the default description
            if coaching != step.description {
                return coaching
            }
        }
        return step.description
    }
    
    @ViewBuilder
    private var nextUpSection: some View {
        if let nextStep = nextStep {
            VStack(alignment: .leading, spacing: 8) {
                Text("NEXT UP")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(getPersonalizedStepName(for: nextStep) ?? nextStep.type.displayName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text(getPersonalizedTargetText(for: nextStep))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Text(nextStep.formattedDuration)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Total Time
            Text("Total: \(formatTime(totalElapsed))")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
            
            // Control Buttons - Side by Side
            HStack(spacing: 24) {
                // Pause/Play Button
                Button {
                    isPaused.toggle()
                    HapticService.shared.medium()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.primary)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
                
                // Stop/End Workout Button
                Button {
                    isPaused = true
                    showEndWorkoutSheet = true
                    HapticService.shared.medium()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(.bottom, 48)
    }
    
    // MARK: - Completion View
    
    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Celebration Icon
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.primary)
            }
            
            Text("Workout Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("Great job finishing \(workout.structure.title)!")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            // Stats
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text(formatTime(totalElapsed))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("Duration")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                VStack(spacing: 4) {
                    Text("\(workout.structure.steps.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text("Steps")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.top, 16)
            
            Spacer()
            
            // Done Button
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.primary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
    
    // MARK: - Timer Functions
    
    private func startWorkout() {
        guard let firstStep = workout.structure.steps.first else { return }
        timeRemaining = firstStep.duration
        startTimer()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            tick()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        guard !isPaused && !isComplete else { return }
        
        totalElapsed += 1
        
        if timeRemaining > 0 {
            timeRemaining -= 1
            HapticService.shared.intervalCountdown(secondsRemaining: timeRemaining)
        } else {
            moveToNextStep()
        }
    }
    
    private func moveToNextStep() {
        let nextIndex = currentStepIndex + 1
        
        if nextIndex >= workout.structure.steps.count {
            isComplete = true
            stopTimer()
        } else {
            currentStepIndex = nextIndex
            timeRemaining = workout.structure.steps[nextIndex].duration
            HapticService.shared.success()
        }
    }
    
    private func skipToNextStep() {
        moveToNextStep()
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - Workout Completion Actions
    
    private func markWorkoutComplete() {
        showEndWorkoutSheet = false
        isComplete = true
        stopTimer()
        // Mark workout as completed in the service
        Task {
            await WorkoutService.shared.markWorkoutCompleted(
                id: workout.id,
                duration: totalElapsed
            )
        }
    }
    
    private func discardWorkout() {
        showEndWorkoutSheet = false
        stopTimer()
        // Mark workout as skipped in the service
        Task {
            await WorkoutService.shared.markWorkoutSkipped(id: workout.id)
        }
        dismiss()
    }
    
    private func submitFeedback(rating: WorkoutRating, rpe: Int?) {
        showFeedbackSheet = false
        
        // Submit feedback and mark workout completed with rating data
        Task {
            await WorkoutService.shared.markWorkoutCompleted(
                id: workout.id,
                duration: totalElapsed,
                rating: rating.rawValue,
                rpe: rpe
            )
        }
        
        print("Feedback submitted - Rating: \(rating.rawValue), RPE: \(String(describing: rpe))")
        
        // Show completion celebration after feedback
        showCompletionCelebration = true
    }
}

// MARK: - End Workout Sheet

struct EndWorkoutSheet: View {
    let workout: Workout
    let totalElapsed: Int
    let stepsCompleted: Int
    let totalSteps: Int
    let onMarkComplete: () -> Void
    let onDiscard: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var progressPercent: Int {
        guard totalSteps > 0 else { return 0 }
        return Int((Double(stepsCompleted) / Double(totalSteps)) * 100)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Handle
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            
            // Header
            Text("End Workout?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Theme.text)
            
            // Progress Summary
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.structure.title)
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        
                        Text("\(stepsCompleted) of \(totalSteps) steps completed")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Text("\(progressPercent)%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.primary)
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.border)
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(Theme.primary)
                            .frame(width: geo.size.width * (Double(stepsCompleted) / Double(max(1, totalSteps))), height: 8)
                    }
                }
                .frame(height: 8)
                
                // Time
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(Theme.textMuted)
                    Text(formatTime(totalElapsed))
                        .foregroundStyle(Theme.textSecondary)
                }
                .font(.subheadline)
            }
            .padding(16)
            .background(Theme.backgroundSecondary)
            .cornerRadius(12)
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                // Mark as Complete
                Button {
                    HapticService.shared.success()
                    onMarkComplete()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Mark as Completed")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.success)
                    .cornerRadius(12)
                }
                
                // Discard
                Button {
                    HapticService.shared.warning()
                    onDiscard()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Discard Workout")
                    }
                    .font(.headline)
                    .foregroundStyle(Theme.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.error.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Continue
                Button {
                    dismiss()
                } label: {
                    Text("Continue Workout")
                        .font(.headline)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.white)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    ActiveWorkoutView(workout: .mock())
        .environmentObject(AuthService.shared)
}
