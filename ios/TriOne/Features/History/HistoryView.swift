import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedFilter: WorkoutType? = nil
    @State private var selectedTimeRange: TimeRange = .month
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary Header
                summaryHeader
                
                // Filters
                filterSection
                
                // Activity List
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.filteredActivities.isEmpty {
                    emptyState
                } else {
                    activityList
                }
            }
            .background(Theme.backgroundSecondary)
            .navigationTitle("History")
            .task {
                await viewModel.loadActivities()
            }
            .refreshable {
                await viewModel.loadActivities()
            }
        }
    }
    
    // MARK: - Summary Header
    
    private var summaryHeader: some View {
        VStack(spacing: 16) {
            // Time Range Picker
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .onChange(of: selectedTimeRange) { _, newValue in
                viewModel.timeRange = newValue
            }
            
            // Stats Row
            HStack(spacing: 0) {
                StatCard(
                    value: "\(viewModel.totalWorkouts)",
                    label: "Workouts",
                    icon: "checkmark.circle.fill",
                    color: Theme.success
                )
                
                Divider()
                    .frame(height: 40)
                
                StatCard(
                    value: viewModel.formattedTotalDuration,
                    label: "Duration",
                    icon: "clock.fill",
                    color: Theme.primary
                )
                
                Divider()
                    .frame(height: 40)
                
                StatCard(
                    value: viewModel.formattedTotalDistance,
                    label: "Distance",
                    icon: "location.fill",
                    color: Theme.bike
                )
            }
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(16)
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 16)
        .background(Color.white)
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    isSelected: selectedFilter == nil,
                    color: Theme.primary
                ) {
                    selectedFilter = nil
                    viewModel.typeFilter = nil
                }
                
                ForEach(WorkoutType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.displayName,
                        isSelected: selectedFilter == type,
                        color: type.color
                    ) {
                        selectedFilter = type
                        viewModel.typeFilter = type
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Activity List
    
    private var activityList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.groupedActivities, id: \.date) { group in
                    Section {
                        ForEach(group.activities) { activity in
                            NavigationLink(destination: ActivityDetailView(activity: activity)) {
                                ActivityRow(activity: activity)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text(group.formattedDate)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.textSecondary)
                            
                            Spacer()
                            
                            Text("\(group.activities.count) workout\(group.activities.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(Theme.textMuted)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Theme.backgroundSecondary)
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64))
                .foregroundStyle(Theme.textMuted)
            
            Text("No Workouts Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Theme.text)
            
            Text("Complete your first workout to see it here!")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.text)
            }
            
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : Theme.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? color : Theme.backgroundSecondary)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? color : Theme.border, lineWidth: 1)
                )
        }
    }
}

struct ActivityRow: View {
    let activity: Activity
    
    var body: some View {
        HStack(spacing: 16) {
            // Type Icon
            ZStack {
                Circle()
                    .fill(activity.workoutType.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: activity.workoutType.icon)
                    .font(.title3)
                    .foregroundStyle(activity.workoutType.color)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.text)
                
                HStack(spacing: 12) {
                    Label(activity.formattedDuration, systemImage: "clock")
                    
                    if let distance = activity.formattedDistance {
                        Label(distance, systemImage: "location")
                    }
                    
                    if let hr = activity.avgHeartRate {
                        Label("\(hr) bpm", systemImage: "heart.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            }
            
            Spacer()
            
            // Time
            VStack(alignment: .trailing, spacing: 2) {
                Text(activity.formattedTime)
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.white)
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
}

