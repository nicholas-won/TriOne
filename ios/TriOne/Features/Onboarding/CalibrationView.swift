import SwiftUI

struct CalibrationView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    @State private var swimMinutes = ""
    @State private var swimSeconds = ""
    @State private var runMinutes = ""
    @State private var runSeconds = ""
    @State private var bikeFTP = ""
    
    @State private var swimUnknown = false
    @State private var runUnknown = false
    @State private var bikeUnknown = false
    
    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(currentStep: 4, totalSteps: 5)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    backButton
                    headerSection
                    swimSection
                    runSection
                    bikeSection
                    calibrationNotice
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            
            continueButton
        }
        .background(Color.white)
        .navigationBarBackButtonHidden()
    }
    
    // MARK: - Subviews
    
    private var backButton: some View {
        Button {
            viewModel.goBack()
        } label: {
            Image(systemName: "arrow.left")
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.text)
                .frame(width: 40, height: 40)
                .background(Theme.backgroundSecondary)
                .clipShape(Circle())
        }
        .padding(.top, 16)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your current fitness")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Theme.text)
            
            Text("Enter what you know – we'll test the rest")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 32)
    }
    
    private var swimSection: some View {
        MetricInputSection(
            icon: "drop.fill",
            iconColor: Theme.swim,
            title: "100m Swim Pace",
            subtitle: "How fast can you swim 100m at a steady pace?",
            isUnknown: $swimUnknown
        ) {
            swimInputFields
        }
        .padding(.bottom, 24)
    }
    
    private var swimInputFields: some View {
        HStack(spacing: 8) {
            TextField("2", text: $swimMinutes)
                .frame(width: 50)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .disabled(swimUnknown)
            
            Text(":")
                .foregroundStyle(Theme.textMuted)
            
            TextField("00", text: $swimSeconds)
                .frame(width: 50)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .disabled(swimUnknown)
            
            Text("/ 100m")
                .foregroundStyle(Theme.textMuted)
        }
    }
    
    private var runSection: some View {
        MetricInputSection(
            icon: "figure.run",
            iconColor: Theme.run,
            title: "5K Run Time",
            subtitle: "Your best recent 5K time",
            isUnknown: $runUnknown
        ) {
            runInputFields
        }
        .padding(.bottom, 24)
    }
    
    private var runInputFields: some View {
        HStack(spacing: 8) {
            TextField("25", text: $runMinutes)
                .frame(width: 50)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .disabled(runUnknown)
            
            Text(":")
                .foregroundStyle(Theme.textMuted)
            
            TextField("00", text: $runSeconds)
                .frame(width: 50)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .disabled(runUnknown)
        }
    }
    
    private var bikeSection: some View {
        MetricInputSection(
            icon: "bicycle",
            iconColor: Theme.bike,
            title: "Bike FTP",
            subtitle: "Functional Threshold Power in watts",
            isUnknown: $bikeUnknown
        ) {
            bikeInputFields
        }
    }
    
    private var bikeInputFields: some View {
        HStack(spacing: 8) {
            TextField("200", text: $bikeFTP)
                .frame(width: 80)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .disabled(bikeUnknown)
            
            Text("watts")
                .foregroundStyle(Theme.textMuted)
        }
    }
    
    @ViewBuilder
    private var calibrationNotice: some View {
        if swimUnknown || runUnknown || bikeUnknown {
            CalibrationWeekNotice()
                .padding(.top, 24)
        }
    }
    
    private var continueButton: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button {
                saveMetrics()
                viewModel.navigateTo(.hardware)
            } label: {
                Text("Continue")
                    .primaryButtonStyle()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color.white)
    }
    
    // MARK: - Actions
    
    private func saveMetrics() {
        if !swimUnknown, let mins = Int(swimMinutes) {
            let secs = Int(swimSeconds) ?? 0
            viewModel.swimPace = mins * 60 + secs
        }
        
        if !runUnknown, let mins = Int(runMinutes) {
            let secs = Int(runSeconds) ?? 0
            let total5KSeconds = mins * 60 + secs
            let pacePerMile = (total5KSeconds / 3) + 30
            viewModel.runPace = pacePerMile
        }
        
        if !bikeUnknown, let ftp = Int(bikeFTP) {
            viewModel.bikePower = ftp
        }
    }
}

// MARK: - Calibration Week Notice
struct CalibrationWeekNotice: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "flask.fill")
                .foregroundStyle(Theme.warning)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Calibration Week")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(hex: "92400E"))
                
                Text("Since you don't know some metrics, your first week will include test workouts to determine your baselines.")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "B45309"))
            }
        }
        .padding(16)
        .background(Color(hex: "FEF3C7"))
        .cornerRadius(12)
    }
}

// MARK: - Metric Input Section
struct MetricInputSection<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isUnknown: Bool
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            iconAndTitle
            subtitleText
            inputRow
        }
    }
    
    private var iconAndTitle: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(iconColor)
            }
            
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.text)
        }
    }
    
    private var subtitleText: some View {
        Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
    }
    
    private var inputRow: some View {
        HStack {
            HStack {
                content
            }
            .padding(16)
            .background(Theme.backgroundSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .opacity(isUnknown ? 0.5 : 1)
            
            unknownButton
        }
    }
    
    private var unknownButton: some View {
        Button {
            HapticService.shared.selection()
            isUnknown.toggle()
        } label: {
            Text("?")
                .font(.headline)
                .foregroundStyle(isUnknown ? Theme.primary : Theme.textMuted)
                .frame(width: 50, height: 50)
                .background(isUnknown ? Theme.primary.opacity(0.1) : Color.clear)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isUnknown ? Theme.primary : Theme.border, lineWidth: isUnknown ? 2 : 1)
                )
        }
    }
}

#Preview {
    NavigationStack {
        CalibrationView()
            .environmentObject(OnboardingViewModel())
    }
}
