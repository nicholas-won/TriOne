import SwiftUI

struct CalibrationResultView: View {
    let testType: CalibrationTestType
    let onSubmit: (CalibrationResult) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var primaryValue: String = ""
    @State private var secondaryValue: String = ""
    @State private var avgHeartRate: String = ""
    @State private var notes: String = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Test-specific input
                    inputSection
                    
                    // Heart Rate (optional)
                    heartRateSection
                    
                    // Notes (optional)
                    notesSection
                    
                    // Calculated value preview
                    if let calculated = calculatedValue {
                        calculatedSection(calculated)
                    }
                }
                .padding(24)
            }
            .background(Theme.backgroundSecondary)
            .navigationTitle("Enter Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        submitResult()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.primary)
                    .disabled(!isValid || isSubmitting)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(testType.color.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: testType.icon)
                    .font(.largeTitle)
                    .foregroundStyle(testType.color)
            }
            
            Text(testType.displayName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Theme.text)
            
            Text(testType.instructions)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Result")
                .font(.headline)
                .foregroundStyle(Theme.text)
            
            switch testType {
            case .swim400m:
                // Time input for swim test
                TimeInputField(
                    label: "400m Time",
                    minutes: $primaryValue,
                    seconds: $secondaryValue
                )
                
            case .run1Mile:
                // Time input for run test
                TimeInputField(
                    label: "1 Mile Time",
                    minutes: $primaryValue,
                    seconds: $secondaryValue
                )
                
            case .bike20Min:
                // Power input for bike test
                VStack(alignment: .leading, spacing: 8) {
                    Text("Average Power")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    
                    HStack(spacing: 8) {
                        TextField("", text: $primaryValue)
                            .keyboardType(.numberPad)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .frame(width: 120)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                        
                        Text("watts")
                            .font(.headline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Heart Rate Section
    
    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Average Heart Rate")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                
                Text("(Optional)")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
            
            HStack(spacing: 8) {
                TextField("", text: $avgHeartRate)
                    .keyboardType(.numberPad)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                
                Text("bpm")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                
                Text("(Optional)")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
            
            TextField("How did the test feel?", text: $notes, axis: .vertical)
                .lineLimit(3...5)
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Calculated Section
    
    private func calculatedSection(_ value: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.warning)
                
                Text("Your \(testType.metricName)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.text)
            }
            
            Text(value)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(testType.color)
            
            Text(testType.metricDescription)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(testType.color.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Validation
    
    private var isValid: Bool {
        switch testType {
        case .swim400m, .run1Mile:
            guard let minutes = Int(primaryValue), let seconds = Int(secondaryValue) else {
                return false
            }
            return minutes >= 0 && seconds >= 0 && seconds < 60 && (minutes > 0 || seconds > 0)
            
        case .bike20Min:
            guard let watts = Int(primaryValue) else { return false }
            return watts > 0 && watts < 1000
        }
    }
    
    private var calculatedValue: String? {
        guard isValid else { return nil }
        
        switch testType {
        case .swim400m:
            guard let minutes = Int(primaryValue), let seconds = Int(secondaryValue) else { return nil }
            let totalSeconds = minutes * 60 + seconds
            // CSS is typically swim pace, so per 100m
            let per100m = totalSeconds / 4
            let mins = per100m / 60
            let secs = per100m % 60
            return String(format: "%d:%02d /100m", mins, secs)
            
        case .run1Mile:
            guard let minutes = Int(primaryValue), let seconds = Int(secondaryValue) else { return nil }
            // Threshold pace is approximately mile time + 10-15%
            let totalSeconds = Double(minutes * 60 + seconds)
            let thresholdPace = Int(totalSeconds * 1.05) // 5% slower for threshold
            let mins = thresholdPace / 60
            let secs = thresholdPace % 60
            return String(format: "%d:%02d /mile", mins, secs)
            
        case .bike20Min:
            guard let watts = Int(primaryValue) else { return nil }
            // FTP is typically 95% of 20-minute power
            let ftp = Int(Double(watts) * 0.95)
            return "\(ftp)W FTP"
        }
    }
    
    // MARK: - Submit
    
    private func submitResult() {
        isSubmitting = true
        
        var result = CalibrationResult(testType: testType)
        
        switch testType {
        case .swim400m:
            if let minutes = Int(primaryValue), let seconds = Int(secondaryValue) {
                let totalSeconds = minutes * 60 + seconds
                result.swimTime400m = totalSeconds
                result.cssPace = totalSeconds / 4 // per 100m
            }
            
        case .run1Mile:
            if let minutes = Int(primaryValue), let seconds = Int(secondaryValue) {
                let totalSeconds = minutes * 60 + seconds
                result.runTime1Mile = totalSeconds
                result.thresholdPace = Int(Double(totalSeconds) * 1.05)
            }
            
        case .bike20Min:
            if let watts = Int(primaryValue) {
                result.bike20MinPower = watts
                result.ftp = Int(Double(watts) * 0.95)
            }
        }
        
        if let hr = Int(avgHeartRate) {
            result.avgHeartRate = hr
        }
        
        result.notes = notes.isEmpty ? nil : notes
        
        onSubmit(result)
        dismiss()
    }
}

// MARK: - Time Input Field

struct TimeInputField: View {
    let label: String
    @Binding var minutes: String
    @Binding var seconds: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            
            HStack(spacing: 8) {
                TextField("", text: $minutes)
                    .keyboardType(.numberPad)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .frame(width: 60)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                
                Text(":")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.text)
                
                TextField("", text: $seconds)
                    .keyboardType(.numberPad)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .frame(width: 60)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                
                VStack(alignment: .leading) {
                    Text("min")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                    Text("sec")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
    }
}

// MARK: - Models

enum CalibrationTestType {
    case swim400m
    case run1Mile
    case bike20Min
    
    var displayName: String {
        switch self {
        case .swim400m: return "400m Swim Test"
        case .run1Mile: return "1 Mile Run Test"
        case .bike20Min: return "20 Minute Bike Test"
        }
    }
    
    var instructions: String {
        switch self {
        case .swim400m:
            return "Enter your time for the 400m swim. We'll calculate your CSS (Critical Swim Speed)."
        case .run1Mile:
            return "Enter your time for the 1 mile run. We'll calculate your threshold pace."
        case .bike20Min:
            return "Enter your average power for the 20 minute test. We'll calculate your FTP."
        }
    }
    
    var icon: String {
        switch self {
        case .swim400m: return "drop.fill"
        case .run1Mile: return "figure.run"
        case .bike20Min: return "bicycle"
        }
    }
    
    var color: Color {
        switch self {
        case .swim400m: return Theme.swim
        case .run1Mile: return Theme.run
        case .bike20Min: return Theme.bike
        }
    }
    
    var metricName: String {
        switch self {
        case .swim400m: return "CSS Pace"
        case .run1Mile: return "Threshold Pace"
        case .bike20Min: return "Functional Threshold Power"
        }
    }
    
    var metricDescription: String {
        switch self {
        case .swim400m:
            return "Critical Swim Speed - the pace you can maintain for longer swims"
        case .run1Mile:
            return "The pace you can sustain for about 60 minutes of running"
        case .bike20Min:
            return "The power you can sustain for about 60 minutes of cycling"
        }
    }
}

struct CalibrationResult {
    let testType: CalibrationTestType
    var swimTime400m: Int? // seconds
    var cssPace: Int? // seconds per 100m
    var runTime1Mile: Int? // seconds
    var thresholdPace: Int? // seconds per mile
    var bike20MinPower: Int? // watts
    var ftp: Int? // watts
    var avgHeartRate: Int?
    var notes: String?
}

#Preview {
    CalibrationResultView(testType: .swim400m) { result in
        print("Result: \(result)")
    }
}

