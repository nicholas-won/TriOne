import SwiftUI

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @State private var selectedTimeRange: TimeRange = .month
    
    enum TimeRange: String, CaseIterable {
        case week = "7D"
        case month = "30D"
        case threeMonths = "3M"
        case year = "1Y"
        case all = "All"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Time Range Selector
                    timeRangeSelector
                    
                    // Overview Cards
                    overviewSection
                    
                    // Volume Chart
                    volumeChartSection
                    
                    // Discipline Breakdown
                    disciplineBreakdownSection
                    
                    // Personal Records
                    personalRecordsSection
                    
                    // Trends
                    trendsSection
                }
                .padding(24)
            }
            .background(Theme.backgroundSecondary)
            .navigationTitle("Statistics")
        }
        .task {
            await viewModel.loadStats(for: selectedTimeRange)
        }
        .onChange(of: selectedTimeRange) { _, newRange in
            Task {
                await viewModel.loadStats(for: newRange)
            }
        }
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        HStack(spacing: 4) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    selectedTimeRange = range
                } label: {
                    Text(range.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(selectedTimeRange == range ? .white : Theme.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedTimeRange == range ? Theme.primary : Color.clear)
                        .cornerRadius(20)
                }
            }
        }
        .padding(4)
        .background(Color.white)
        .cornerRadius(24)
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            OverviewStatCard(
                title: "Workouts",
                value: "\(viewModel.totalWorkouts)",
                trend: viewModel.workoutsTrend,
                icon: "figure.run",
                color: Theme.primary
            )
            
            OverviewStatCard(
                title: "Total Time",
                value: viewModel.formattedTotalTime,
                trend: viewModel.timeTrend,
                icon: "clock.fill",
                color: Theme.success
            )
            
            OverviewStatCard(
                title: "Distance",
                value: viewModel.formattedTotalDistance,
                trend: viewModel.distanceTrend,
                icon: "location.fill",
                color: Theme.bike
            )
            
            OverviewStatCard(
                title: "Avg Duration",
                value: viewModel.formattedAvgDuration,
                trend: nil,
                icon: "timer",
                color: Theme.warning
            )
        }
    }
    
    // MARK: - Volume Chart Section
    
    private var volumeChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Training Volume")
                .font(.headline)
                .foregroundStyle(Theme.text)
            
            // Simple bar chart
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(viewModel.weeklyVolume, id: \.week) { data in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(data.isCurrentWeek ? Theme.primary : Theme.primary.opacity(0.5))
                            .frame(width: 32, height: max(8, CGFloat(data.hours) * 20))
                        
                        Text(data.label)
                            .font(.caption2)
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            
            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.primary)
                        .frame(width: 8, height: 8)
                    Text("This week")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.primary.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text("Previous weeks")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Discipline Breakdown
    
    private var disciplineBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("By Discipline")
                .font(.headline)
                .foregroundStyle(Theme.text)
            
            ForEach(viewModel.disciplineStats, id: \.type) { stat in
                DisciplineRow(stat: stat)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Personal Records
    
    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Personal Records")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                
                Spacer()
                
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Theme.warning)
            }
            
            ForEach(viewModel.personalRecords, id: \.title) { record in
                PersonalRecordRow(record: record)
            }
            
            if viewModel.personalRecords.isEmpty {
                Text("Complete more workouts to set records!")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // MARK: - Trends
    
    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights")
                .font(.headline)
                .foregroundStyle(Theme.text)
            
            ForEach(viewModel.insights, id: \.title) { insight in
                InsightRow(insight: insight)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
}

// MARK: - Supporting Views

struct OverviewStatCard: View {
    let title: String
    let value: String
    let trend: Double?
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                
                Spacer()
                
                if let trend = trend {
                    TrendBadge(value: trend)
                }
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Theme.text)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
}

struct TrendBadge: View {
    let value: Double
    
    var isPositive: Bool { value >= 0 }
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            
            Text("\(abs(Int(value * 100)))%")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(isPositive ? Theme.success : Theme.error)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isPositive ? Theme.success.opacity(0.1) : Theme.error.opacity(0.1))
        .cornerRadius(12)
    }
}

struct DisciplineRow: View {
    let stat: DisciplineStat
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(stat.type.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: stat.type.icon)
                    .foregroundStyle(stat.type.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.text)
                
                Text("\(stat.count) workouts • \(stat.formattedDuration)")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            
            Spacer()
            
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Theme.border, lineWidth: 4)
                    .frame(width: 44, height: 44)
                
                Circle()
                    .trim(from: 0, to: stat.percentage)
                    .stroke(stat.type.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(stat.percentage * 100))%")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.text)
            }
        }
    }
}

struct PersonalRecordRow: View {
    let record: PersonalRecord
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.warning.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "trophy.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.text)
                
                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            
            Spacer()
            
            Text(record.value)
                .font(.headline)
                .foregroundStyle(Theme.primary)
        }
        .padding(.vertical, 4)
    }
}

struct InsightRow: View {
    let insight: Insight
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.icon)
                .font(.title3)
                .foregroundStyle(insight.color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.text)
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Model

@MainActor
class StatsViewModel: ObservableObject {
    @Published var totalWorkouts = 0
    @Published var totalTimeSeconds = 0
    @Published var totalDistanceMeters = 0
    @Published var avgDurationSeconds = 0
    
    @Published var workoutsTrend: Double? = nil
    @Published var timeTrend: Double? = nil
    @Published var distanceTrend: Double? = nil
    
    @Published var weeklyVolume: [WeeklyVolume] = []
    @Published var disciplineStats: [DisciplineStat] = []
    @Published var personalRecords: [PersonalRecord] = []
    @Published var insights: [Insight] = []
    
    var formattedTotalTime: String {
        let hours = totalTimeSeconds / 3600
        let minutes = (totalTimeSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    var formattedTotalDistance: String {
        let miles = Double(totalDistanceMeters) / 1609.34
        return String(format: "%.1f mi", miles)
    }
    
    var formattedAvgDuration: String {
        let minutes = avgDurationSeconds / 60
        return "\(minutes)m"
    }
    
    func loadStats(for range: StatsView.TimeRange) async {
        // Mock data for now
        totalWorkouts = Int.random(in: 8...25)
        totalTimeSeconds = Int.random(in: 14400...36000) // 4-10 hours
        totalDistanceMeters = Int.random(in: 30000...100000)
        avgDurationSeconds = totalWorkouts > 0 ? totalTimeSeconds / totalWorkouts : 0
        
        workoutsTrend = Double.random(in: -0.2...0.3)
        timeTrend = Double.random(in: -0.15...0.25)
        distanceTrend = Double.random(in: -0.1...0.2)
        
        // Weekly volume
        weeklyVolume = (0..<6).map { week in
            WeeklyVolume(
                week: week,
                hours: Double.random(in: 2...8),
                label: "W\(6-week)",
                isCurrentWeek: week == 5
            )
        }
        
        // Discipline stats
        let types: [WorkoutType] = [.swim, .bike, .run, .strength]
        let counts = types.map { _ in Int.random(in: 2...8) }
        let total = counts.reduce(0, +)
        
        disciplineStats = zip(types, counts).map { type, count in
            DisciplineStat(
                type: type,
                count: count,
                durationSeconds: count * Int.random(in: 2400...4200),
                percentage: Double(count) / Double(total)
            )
        }
        
        // Personal records
        personalRecords = [
            PersonalRecord(title: "Longest Ride", value: "42.5 mi", date: Date().addingTimeInterval(-86400 * 5)),
            PersonalRecord(title: "Fastest 5K", value: "24:32", date: Date().addingTimeInterval(-86400 * 12)),
            PersonalRecord(title: "Longest Swim", value: "2,000m", date: Date().addingTimeInterval(-86400 * 8))
        ]
        
        // Insights
        insights = [
            Insight(
                icon: "flame.fill",
                title: "Consistency is Key",
                description: "You've worked out 5 days in a row! Keep it up.",
                color: Theme.warning
            ),
            Insight(
                icon: "chart.line.uptrend.xyaxis",
                title: "Volume Increasing",
                description: "Your weekly training volume is up 15% from last month.",
                color: Theme.success
            ),
            Insight(
                icon: "drop.fill",
                title: "More Swim Time",
                description: "Consider adding more swim sessions to balance your training.",
                color: Theme.swim
            )
        ]
    }
}

// MARK: - Data Models

struct WeeklyVolume {
    let week: Int
    let hours: Double
    let label: String
    let isCurrentWeek: Bool
}

struct DisciplineStat {
    let type: WorkoutType
    let count: Int
    let durationSeconds: Int
    let percentage: Double
    
    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct PersonalRecord {
    let title: String
    let value: String
    let date: Date
}

struct Insight {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

#Preview {
    StatsView()
}

