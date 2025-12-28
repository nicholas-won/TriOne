import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss
    @StateObject private var workoutService = WorkoutService.shared
    
    // Get the current status from the service (in case it was updated)
    private var currentWorkout: Workout {
        workoutService.getWorkout(by: workout.id) ?? workout
    }
    
    private var isCompleted: Bool {
        currentWorkout.status == .completed
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
                        .fill(currentWorkout.color)
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
                    
                    Text(currentWorkout.structure.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.text)
                }
                
                Spacer()
            }
            
            HStack(spacing: 24) {
                Label(currentWorkout.structure.formattedDuration, systemImage: "clock")
                Label("\(currentWorkout.structure.steps.count) steps", systemImage: "list.number")
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(currentWorkout.color.opacity(0.1))
    }
    
    // MARK: - Purpose Section
    
    private var purposeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Theme.warning)
                
                Text("Today's Purpose")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
            }
            
            Text(currentWorkout.structure.description)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.white)
    }
    
    // MARK: - Intensity Section
    
    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Intensity Profile")
                .font(.headline)
                .foregroundStyle(Theme.text)
            
            IntensityChart(steps: currentWorkout.structure.steps, color: currentWorkout.color)
            
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
                WorkoutStepRow(step: step, index: index, color: currentWorkout.color)
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
                        .background(currentWorkout.color)
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

struct IntensityChart: View {
    let steps: [WorkoutStep]
    let color: Color
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(steps) { step in
                let intensity = Double(step.targetZone ?? (step.isIntense ? 4 : 2))
                let height = (intensity / 6.0) * 64
                
                Rectangle()
                    .fill(step.type == .rest ? Theme.border : color)
                    .frame(height: height)
                    .cornerRadius(2)
                    .opacity(step.type == .rest ? 0.5 : 1)
            }
        }
        .frame(height: 64)
        .padding(12)
        .background(Theme.backgroundSecondary)
        .cornerRadius(12)
    }
}

struct WorkoutStepRow: View {
    let step: WorkoutStep
    let index: Int
    let color: Color
    
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
                Text(step.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.text)
                
                Text(step.targetText)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                
                if let description = step.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }
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
    }
}
