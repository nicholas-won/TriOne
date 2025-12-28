import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var workoutService = WorkoutService.shared
    
    // Get the current status from the service (in case it was updated)
    private var currentWorkout: Workout {
        workoutService.getWorkout(by: workout.id) ?? workout
    }
    
    private var isCompleted: Bool {
        currentWorkout.status == .completed
    }
    
    // Personalized calculator
    private var calculator: PersonalizedWorkoutCalculator? {
        guard let biometrics = authService.currentUser?.biometrics else { return nil }
        return PersonalizedWorkoutCalculator(
            biometrics: biometrics,
            workoutType: currentWorkout.workoutType
        )
    }
    
    // Personalized title
    private var personalizedTitle: String {
        WorkoutTitleGenerator.generateTitle(
            for: currentWorkout.structure,
            type: currentWorkout.workoutType
        )
    }
    
    // Personalized "Why"
    private var personalizedWhy: String {
        WorkoutWhyGenerator.generateWhy(
            for: currentWorkout.structure,
            type: currentWorkout.workoutType
        )
    }
    
    // Calculate TSS (Training Stress Score) - simplified
    private var estimatedTSS: Int {
        let totalMinutes = currentWorkout.structure.totalDuration / 60
        let avgIntensity = currentWorkout.structure.steps.compactMap { $0.targetZone }.reduce(0, +) / max(currentWorkout.structure.steps.count, 1)
        return Int(Double(totalMinutes) * (Double(avgIntensity) / 4.0) * 0.7) // Rough estimate
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    purposeSection
                    Divider()
                    intensitySection
                    Divider()
                    structureSection
                }
            }
            .background(Color.white)
            
            bottomCTA
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.primary)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: currentWorkout.icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(currentWorkout.workoutType.displayName.uppercased())
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        
                        if isCompleted {
                            Label("Completed", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.success)
                        }
                    }
                    
                    Text(personalizedTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.text)
                }
                
                Spacer()
            }
            
            HStack(spacing: 24) {
                Label(currentWorkout.structure.formattedDuration, systemImage: "clock")
                Label("\(estimatedTSS) TSS", systemImage: "chart.bar.fill")
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Theme.primary.opacity(0.1))
    }
    
    // MARK: - Purpose Section (The "Why")
    
    private var purposeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(personalizedWhy)
                .font(.subheadline)
                .italic()
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.backgroundSecondary)
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
    
    // MARK: - Intensity Section
    
    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Intensity Profile")
                .font(.headline)
                .foregroundStyle(Theme.text)
            
            PersonalizedIntensityChart(
                steps: currentWorkout.structure.steps,
                color: Theme.primary,
                totalDuration: currentWorkout.structure.totalDuration
            )
            
            HStack {
                Text("Start")
                Spacer()
                Text("End")
            }
            .font(.caption)
            .foregroundStyle(Theme.textMuted)
        }
        .padding(24)
    }
    
    // MARK: - Structure Section
    
    private var structureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workout Structure")
                .font(.headline)
                .foregroundStyle(Theme.text)
            
            ForEach(Array(currentWorkout.structure.steps.enumerated()), id: \.element.id) { index, step in
                PersonalizedWorkoutStepRow(
                    step: step,
                    index: index,
                    calculator: calculator,
                    color: Theme.primary
                )
            }
        }
        .padding(24)
        .padding(.bottom, 100)
    }
    
    // MARK: - Bottom CTA
    
    private var bottomCTA: some View {
        VStack {
            Divider()
            
            if isCompleted {
                // Completed state
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.success)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Workout Completed")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        
                        Text("Great job! You crushed it.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            } else {
                // Start workout button
                NavigationLink(destination: ActiveWorkoutView(workout: currentWorkout)) {
                    Text("Start Workout")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .background(Color.white)
    }
    
    // MARK: - Back Button
    
    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "arrow.left")
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.text)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.8))
                .clipShape(Circle())
        }
    }
}

struct PersonalizedIntensityChart: View {
    let steps: [WorkoutStep]
    let color: Color
    let totalDuration: Int
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(steps) { step in
                    let intensity = Double(step.targetZone ?? (step.isIntense ? 4 : 2))
                    let height = (intensity / 6.0) * 64
                    let width = (Double(step.duration) / Double(totalDuration)) * geometry.size.width
                    
                    Rectangle()
                        .fill(step.type == .rest ? Theme.border : color)
                        .frame(width: max(width, 4), height: height)
                        .cornerRadius(2)
                        .opacity(step.type == .rest ? 0.5 : 1)
                }
            }
        }
        .frame(height: 64)
        .padding(12)
        .background(Theme.backgroundSecondary)
        .cornerRadius(12)
    }
}

struct PersonalizedWorkoutStepRow: View {
    let step: WorkoutStep
    let index: Int
    let calculator: PersonalizedWorkoutCalculator?
    let color: Color
    
    private var stepName: String {
        // Generate more descriptive step names
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
    
    private var targetText: String {
        if let calculator = calculator {
            return calculator.getPersonalizedTargetText(for: step)
        }
        return step.targetText
    }
    
    private var coachingText: String {
        if let calculator = calculator {
            return calculator.getPersonalizedCoaching(for: step)
        }
        return step.description ?? "Maintain steady effort"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(step.isIntense ? color : Theme.backgroundSecondary)
                    .frame(width: 40, height: 40)
                
                Text("\(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(step.isIntense ? .white : Theme.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(stepName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.text)
                
                Text(targetText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textSecondary)
                
                Text(coachingText)
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
            
            Spacer()
            
            Text(step.formattedDuration)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Theme.text)
        }
        .padding(16)
        .background(step.isIntense ? color.opacity(0.05) : Color.clear)
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: .mock())
            .environmentObject(AuthService.shared)
    }
}
