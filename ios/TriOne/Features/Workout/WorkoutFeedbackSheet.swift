import SwiftUI

enum WorkoutRating: String, CaseIterable {
    case easier = "easier"
    case same = "same"
    case harder = "harder"
    
    var displayName: String {
        switch self {
        case .easier: return "Easier"
        case .same: return "As Expected"
        case .harder: return "Harder"
        }
    }
    
    var icon: String {
        switch self {
        case .easier: return "arrow.down.circle.fill"
        case .same: return "equal.circle.fill"
        case .harder: return "arrow.up.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .easier: return Theme.success
        case .same: return Theme.primary
        case .harder: return Theme.warning
        }
    }
    
    var description: String {
        switch self {
        case .easier: return "I could have done more"
        case .same: return "Right on target"
        case .harder: return "That was tough!"
        }
    }
}

struct WorkoutFeedbackSheet: View {
    let workout: Workout
    let totalDuration: Int
    let onSubmit: (WorkoutRating, Int?) -> Void
    let onSkip: () -> Void
    
    @State private var selectedRating: WorkoutRating?
    @State private var rpeScore: Int?
    @State private var showRPE = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(workout.color.opacity(0.2))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "checkmark")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(workout.color)
                }
                
                Text("Workout Complete!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.text)
                
                Text(workout.structure.title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 32)
            
            // Rating Question
            VStack(alignment: .leading, spacing: 16) {
                Text("How did that feel?")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                
                Text("Compared to what you expected")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                
                // Rating Options
                HStack(spacing: 12) {
                    ForEach(WorkoutRating.allCases, id: \.self) { rating in
                        RatingButton(
                            rating: rating,
                            isSelected: selectedRating == rating
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedRating = rating
                            }
                            HapticService.shared.selection()
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            
            // RPE Section (Optional)
            if showRPE {
                rpeSection
                    .padding(.top, 24)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Spacer()
            
            // Info about adaptation
            if selectedRating == .harder {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Theme.warning)
                    
                    Text("We'll keep an eye on this. If workouts continue to feel harder, we'll adjust your plan to help you recover.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(12)
                .background(Theme.warning.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            
            // Buttons
            VStack(spacing: 12) {
                Button {
                    HapticService.shared.success()
                    onSubmit(selectedRating ?? .same, rpeScore)
                } label: {
                    Text("Submit Feedback")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedRating != nil ? workout.color : Theme.textMuted)
                        .cornerRadius(12)
                }
                .disabled(selectedRating == nil)
                
                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.white)
        .onChange(of: selectedRating) { _, rating in
            if rating != nil && !showRPE {
                withAnimation(.easeInOut(duration: 0.3).delay(0.2)) {
                    showRPE = true
                }
            }
        }
    }
    
    private var rpeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rate of Perceived Exertion")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.text)
                
                Text("(Optional)")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
            
            // RPE Scale
            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { score in
                    Button {
                        rpeScore = score
                        HapticService.shared.light()
                    } label: {
                        Text("\(score)")
                            .font(.subheadline)
                            .fontWeight(rpeScore == score ? .bold : .medium)
                            .foregroundStyle(rpeScore == score ? .white : rpeColor(for: score))
                            .frame(width: 32, height: 32)
                            .background(rpeScore == score ? rpeColor(for: score) : rpeColor(for: score).opacity(0.15))
                            .cornerRadius(8)
                    }
                }
            }
            
            // RPE Labels
            HStack {
                Text("Easy")
                    .font(.caption2)
                    .foregroundStyle(Theme.success)
                
                Spacer()
                
                Text("Moderate")
                    .font(.caption2)
                    .foregroundStyle(Theme.warning)
                
                Spacer()
                
                Text("Max Effort")
                    .font(.caption2)
                    .foregroundStyle(Theme.error)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private func rpeColor(for score: Int) -> Color {
        switch score {
        case 1...3: return Theme.success
        case 4...6: return Theme.warning
        case 7...8: return .orange
        default: return Theme.error
        }
    }
}

struct RatingButton: View {
    let rating: WorkoutRating
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? rating.color : Theme.backgroundSecondary)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: rating.icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : rating.color)
                }
                
                Text(rating.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? rating.color : Theme.text)
                
                Text(rating.description)
                    .font(.caption2)
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? rating.color.opacity(0.1) : Color.clear)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? rating.color : Theme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WorkoutFeedbackSheet(
        workout: .mock(),
        totalDuration: 2400,
        onSubmit: { rating, rpe in
            print("Rating: \(rating), RPE: \(String(describing: rpe))")
        },
        onSkip: {
            print("Skipped")
        }
    )
}

