import SwiftUI

struct PlanView: View {
    @EnvironmentObject var authService: AuthService
    @Binding var selectedTab: Int
    @StateObject private var viewModel = PlanViewModel()
    @State private var races: [Race] = Race.mockRaces
    @State private var scrollToTodayTrigger = false
    @State private var hasScrolledToToday = false
    @State private var lastScrollPosition: String? = nil
    @State private var isScrollingToToday = false
    
    var selectedRace: Race? {
        guard let primaryRaceId = authService.currentUser?.primaryRaceId else { return nil }
        return races.first { $0.id == primaryRaceId }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month Selector Header
                monthHeader
                
                // Selected Race Info
                if let selectedRace = selectedRace {
                    SelectedRaceInfoCard(race: selectedRace)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                
                // Workout List
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.weekGroups.isEmpty {
                    emptyState
                } else {
                    workoutList
                }
            }
            .background(Theme.backgroundSecondary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Plan")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Direct action - update month and trigger scroll
                        print("🔘 Today button pressed")
                        isScrollingToToday = true
                        hasScrolledToToday = false
                        viewModel.selectedMonth = Date()
                        viewModel.shouldScrollToToday = true
                        scrollToTodayTrigger.toggle()
                        
                        // Post notification as immediate trigger
                        NotificationCenter.default.post(name: NSNotification.Name("ScrollToToday"), object: nil)
                    } label: {
                        Text("Today")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.primary)
                    }
                }
            }
            .task {
                await viewModel.loadWorkouts()
            }
            .refreshable {
                await viewModel.loadWorkouts()
            }
            .onChange(of: authService.currentUser?.primaryRaceId) { _, _ in
                // Reload plan when race selection changes
                Task {
                    await viewModel.loadWorkouts()
                }
            }
        }
    }
    
    // MARK: - Month Header
    
    private var monthHeader: some View {
        HStack {
            Button {
                viewModel.previousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
            }
            
            Spacer()
            
            Text(viewModel.formattedMonth)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.text)
            
            Spacer()
            
            Button {
                viewModel.nextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    
    // MARK: - Workout List
    
    private var workoutList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(viewModel.weekGroups) { week in
                        Section {
                            ForEach(viewModel.dayWorkouts(for: week)) { dayWorkout in
                                DayRow(dayWorkout: dayWorkout)
                                    .id(dayWorkout.id)
                            }
                        } header: {
                            WeekHeader(week: week)
                                .id(week.id)
                        }
                    }
                }
            }
            .onAppear {
                // If we have a saved scroll position, restore it
                if let savedPosition = lastScrollPosition {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            proxy.scrollTo(savedPosition, anchor: .top)
                        }
                    }
                } else if !hasScrolledToToday {
                    // Scroll to today on first load
                    isScrollingToToday = true
                    viewModel.selectedMonth = Date()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        scrollToTodayDate(proxy: proxy)
                        hasScrolledToToday = true
                    }
                }
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                // When Plan tab is selected, scroll to today if not already scrolled
                if newValue == 1 && !hasScrolledToToday {
                    isScrollingToToday = true
                    viewModel.selectedMonth = Date()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollToTodayDate(proxy: proxy)
                        hasScrolledToToday = true
                    }
                } else if newValue == 1, let savedPosition = lastScrollPosition {
                    // Restore saved position
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            proxy.scrollTo(savedPosition, anchor: .top)
                        }
                    }
                }
            }
            .onChange(of: viewModel.selectedMonth) { _, _ in
                // Only scroll to month if we're not intentionally scrolling to today
                if !isScrollingToToday {
                    scrollToSelectedMonth(proxy: proxy)
                } else {
                    // If we're scrolling to today, wait a bit then scroll to today's date
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollToTodayDate(proxy: proxy)
                    }
                }
            }
            .onChange(of: viewModel.shouldScrollToToday) { oldValue, newValue in
                // Scroll when ViewModel triggers it
                if newValue && !oldValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        scrollToTodayDate(proxy: proxy)
                        viewModel.shouldScrollToToday = false
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollToToday"))) { _ in
                // Primary scroll trigger - faster response
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    scrollToTodayDate(proxy: proxy)
                }
            }
            .onChange(of: scrollToTodayTrigger) { oldValue, newValue in
                // Backup scroll trigger
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    scrollToTodayDate(proxy: proxy)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func scrollToTodayDate(proxy: ScrollViewProxy) {
        let calendar = Calendar.current
        let today = Date()
        
        print("📍 scrollToTodayDate called, weekGroups count: \(viewModel.weekGroups.count)")
        
        // Ensure we have week groups loaded
        guard !viewModel.weekGroups.isEmpty else {
            print("⚠️ Cannot scroll: week groups empty")
            isScrollingToToday = false
            return
        }
        
        // Find the week containing today
        guard let currentWeekIndex = viewModel.currentWeekIndex(),
              currentWeekIndex < viewModel.weekGroups.count else {
            print("⚠️ Cannot scroll: current week index not found")
            isScrollingToToday = false
            return
        }
        
        let week = viewModel.weekGroups[currentWeekIndex]
        print("📍 Found week: \(week.id), dates: \(week.startDate) to \(week.endDate)")
        
        // Find today's specific day row
        let dayWorkouts = viewModel.dayWorkouts(for: week)
        print("📍 Day workouts count: \(dayWorkouts.count)")
        for (index, workout) in dayWorkouts.enumerated() {
            print("  Day \(index): \(workout.id), date: \(workout.date), isToday: \(calendar.isDateInToday(workout.date))")
        }
        
        // Always try to scroll to today's specific day row first, fallback to week header
        if let todayWorkout = dayWorkouts.first(where: { calendar.isDateInToday($0.date) }) {
            let todayId = todayWorkout.id
            print("✅ Scrolling to today ID: \(todayId), date: \(todayWorkout.date)")
            
            // Use DispatchQueue to ensure it runs on main thread
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(todayId, anchor: .center)
                    print("✅ Scroll command sent for ID: \(todayId)")
                }
                self.lastScrollPosition = todayId
            }
        } else {
            // Fallback to week header if day not found
            print("⚠️ Today not found in day workouts, scrolling to week header: \(week.id)")
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(week.id, anchor: .top)
                    print("✅ Scroll command sent for week ID: \(week.id)")
                }
                self.lastScrollPosition = week.id
            }
        }
        
        // Reset the flag after scrolling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isScrollingToToday = false
        }
    }
    
    private func scrollToCurrentWeek(proxy: ScrollViewProxy) {
        if let currentIndex = viewModel.currentWeekIndex(),
           currentIndex < viewModel.weekGroups.count {
            let week = viewModel.weekGroups[currentIndex]
            withAnimation {
                proxy.scrollTo(week.id, anchor: .top)
                lastScrollPosition = week.id
            }
        }
    }
    
    private func scrollToSelectedMonth(proxy: ScrollViewProxy) {
        let calendar = Calendar.current
        let selectedMonth = viewModel.selectedMonth
        
        // Find the first week that contains the selected month
        if let firstWeekInMonth = viewModel.weekGroups.first(where: { week in
            calendar.isDate(week.startDate, equalTo: selectedMonth, toGranularity: .month) ||
            calendar.isDate(week.endDate, equalTo: selectedMonth, toGranularity: .month) ||
            (week.startDate <= selectedMonth && week.endDate >= selectedMonth)
        }) {
            withAnimation {
                proxy.scrollTo(firstWeekInMonth.id, anchor: .top)
                lastScrollPosition = firstWeekInMonth.id
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(Theme.textMuted)
            
            Text("No Training Plan")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Theme.text)
            
            Text("Your training plan will appear here once it's generated.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(24)
    }
    
}

// MARK: - Week Header

struct WeekHeader: View {
    let week: WeekGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if week.weekNumber > 0 {
                    Text("Week \(week.weekNumber)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.text)
                    
                    if let phase = week.phase {
                        Text("• \(phase)")
                            .font(.headline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else if week.phase == "Maintenance Phase" {
                    // Maintenance mode: show only phase, no week number
                    Text("Maintenance Phase")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.text)
                } else {
                    Text("Pre-Plan")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.textMuted)
                }
                
                Spacer()
            }
            
            HStack {
                Text(week.formattedDateRange)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                
                Spacer()
                
                if week.weekNumber > 0 || week.phase == "Maintenance Phase" {
                    Text("Target: \(week.formattedTotalDuration)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Theme.backgroundSecondary)
    }
}

// MARK: - Day Row

struct DayRow: View {
    let dayWorkout: DayWorkout
    @EnvironmentObject var authService: AuthService
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(dayWorkout.date)
    }
    
    private var isPast: Bool {
        dayWorkout.date < Date() && !isToday
    }
    
    private var isFuture: Bool {
        dayWorkout.date > Date()
    }
    
    private var workoutState: WorkoutState {
        guard let workout = dayWorkout.workout else {
            return .restDay
        }
        
        if workout.status == .completed {
            return .completed
        } else if workout.status == .missed {
            return .missed
        } else if workout.status == .skipped {
            return .missed
        } else if isToday {
            return .today
        } else if isFuture {
            return .future
        } else {
            return .missed
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Date Bubble
            VStack(spacing: 2) {
                Text(dayWorkout.dayOfWeek)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isToday ? Theme.primary : Theme.textSecondary)
                
                Text(dayWorkout.dayNumber)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(isToday ? Theme.primary : Theme.text)
            }
            .frame(width: 50)
            
            // Workout Info
            if let workout = dayWorkout.workout {
                workoutContent(workout: workout)
            } else {
                restDayContent()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .overlay(
            // Blue border for today
            isToday ?
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Theme.primary, lineWidth: 2)
                    .padding(.leading, -2) :
                nil
        )
    }
    
    private var backgroundColor: Color {
        switch workoutState {
        case .completed:
            return Color.white.opacity(0.6)
        case .missed:
            return Color.white
        case .today:
            return Color.white
        case .future:
            return Color.white
        case .restDay:
            return Color.white.opacity(0.8)
        }
    }
    
    @ViewBuilder
    private func workoutContent(workout: Workout) -> some View {
        Group {
            if workoutState == .today {
                // For today, make the whole row clickable to workout detail, except the Start button
                HStack(spacing: 12) {
                    NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                        HStack(spacing: 12) {
                            // Sport Icon
                            ZStack {
                                Circle()
                                    .fill(workout.workoutType.color.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: workout.workoutType.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(workout.workoutType.color)
                            }
                            
                            // Title and Duration
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.structure.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.text)
                                
                                Text(durationText(for: workout))
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // Status Icon / Start Button
                    statusIndicator(for: workout)
                }
            } else {
                // For other states, make the whole row clickable
                NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                    HStack(spacing: 12) {
                        // Sport Icon
                        ZStack {
                            Circle()
                                .fill(workout.workoutType.color.opacity(0.15))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: workout.workoutType.icon)
                                .font(.subheadline)
                                .foregroundStyle(workout.workoutType.color)
                        }
                        
                        // Title and Duration
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.structure.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(workoutState == .completed ? Theme.textSecondary : Theme.text)
                            
                            Text(durationText(for: workout))
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Status Icon
                        statusIndicator(for: workout)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private func restDayContent() -> some View {
        HStack {
            Text("Rest Day")
                .font(.subheadline)
                .foregroundStyle(Theme.textMuted)
                .italic()
            
            Spacer()
        }
    }
    
    private func durationText(for workout: Workout) -> String {
        let duration = workout.structure.totalDuration
        let minutes = duration / 60
        
        switch workoutState {
        case .completed, .missed:
            return "Completed: \(minutes)m"
        case .today, .future:
            return "Planned: \(minutes)m"
        case .restDay:
            return ""
        }
    }
    
    @ViewBuilder
    private func statusIndicator(for workout: Workout) -> some View {
        switch workoutState {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.success)
        case .missed:
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.error)
        case .today:
            NavigationLink(destination: ActiveWorkoutView(workout: workout)) {
                Text("Start")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.primary)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        case .future:
            Circle()
                .fill(Theme.border)
                .frame(width: 24, height: 24)
        case .restDay:
            EmptyView()
        }
    }
}

enum WorkoutState {
    case completed
    case missed
    case today
    case future
    case restDay
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    PlanView(selectedTab: .constant(1))
        .environmentObject(AuthService.shared)
}

