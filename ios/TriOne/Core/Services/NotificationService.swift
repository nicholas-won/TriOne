import Foundation
import UserNotifications
import UIKit

/// Service for managing push notifications and local workout reminders
@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var deviceToken: String?
    @Published var workoutReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(workoutReminderEnabled, forKey: "workoutReminderEnabled")
            if workoutReminderEnabled {
                scheduleWorkoutReminders()
            } else {
                cancelWorkoutReminders()
            }
        }
    }
    @Published var reminderTime: Date {
        didSet {
            UserDefaults.standard.set(reminderTime, forKey: "reminderTime")
            if workoutReminderEnabled {
                scheduleWorkoutReminders()
            }
        }
    }
    
    private override init() {
        // Load saved preferences
        self.workoutReminderEnabled = UserDefaults.standard.bool(forKey: "workoutReminderEnabled")
        
        if let savedTime = UserDefaults.standard.object(forKey: "reminderTime") as? Date {
            self.reminderTime = savedTime
        } else {
            // Default to 7:00 AM
            var components = DateComponents()
            components.hour = 7
            components.minute = 0
            self.reminderTime = Calendar.current.date(from: components) ?? Date()
        }
        
        super.init()
        
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                isAuthorized = granted
            }
            
            if granted {
                // Register for remote notifications
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                
                // Set ourselves as delegate
                center.delegate = self
            }
            
            return granted
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        await MainActor.run {
            isAuthorized = settings.authorizationStatus == .authorized
        }
        
        // Set delegate
        center.delegate = self
    }
    
    // MARK: - Device Token
    
    func setDeviceToken(_ data: Data) {
        let token = data.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token
        
        // Send to backend
        Task {
            await sendDeviceTokenToServer(token)
        }
    }
    
    private func sendDeviceTokenToServer(_ token: String) async {
        // TODO: Send token to your backend to enable remote push notifications
        print("Device token: \(token)")
        // This would be an API call like:
        // try await APIService.shared.registerDeviceToken(token)
    }
    
    // MARK: - Workout Reminders (Local Notifications)
    
    func scheduleWorkoutReminders() {
        guard isAuthorized && workoutReminderEnabled else { return }
        
        // Cancel existing reminders first
        cancelWorkoutReminders()
        
        // Get the hour and minute from reminderTime
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        
        // Schedule daily workout reminder
        let content = UNMutableNotificationContent()
        content.title = "Time to Train! 💪"
        content.body = "You have a workout scheduled for today. Let's get after it!"
        content.sound = .default
        content.categoryIdentifier = "WORKOUT_REMINDER"
        
        var triggerComponents = DateComponents()
        triggerComponents.hour = components.hour
        triggerComponents.minute = components.minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "daily_workout_reminder",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule workout reminder: \(error)")
            } else {
                print("Scheduled daily workout reminder for \(components.hour ?? 0):\(components.minute ?? 0)")
            }
        }
        
        // Set up notification actions
        setupNotificationCategories()
    }
    
    func cancelWorkoutReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["daily_workout_reminder"]
        )
    }
    
    // MARK: - Upcoming Workout Reminder
    
    func scheduleWorkoutReminder(for workout: Workout, minutesBefore: Int = 30) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Workout Starting Soon"
        content.body = "\(workout.structure.title) starts in \(minutesBefore) minutes"
        content.sound = .default
        content.categoryIdentifier = "UPCOMING_WORKOUT"
        content.userInfo = ["workoutId": workout.id]
        
        // Calculate trigger time
        let reminderDate = workout.scheduledDate.addingTimeInterval(-Double(minutesBefore * 60))
        
        // Only schedule if in the future
        guard reminderDate > Date() else { return }
        
        let triggerComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "workout_\(workout.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule workout reminder: \(error)")
            }
        }
    }
    
    func cancelWorkoutReminder(for workoutId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["workout_\(workoutId)"]
        )
    }
    
    // MARK: - Notification Categories
    
    private func setupNotificationCategories() {
        // Workout reminder category
        let startAction = UNNotificationAction(
            identifier: "START_WORKOUT",
            title: "Start Workout",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Remind in 1 hour",
            options: []
        )
        
        let workoutReminderCategory = UNNotificationCategory(
            identifier: "WORKOUT_REMINDER",
            actions: [startAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Upcoming workout category
        let viewAction = UNNotificationAction(
            identifier: "VIEW_WORKOUT",
            title: "View Details",
            options: [.foreground]
        )
        
        let upcomingWorkoutCategory = UNNotificationCategory(
            identifier: "UPCOMING_WORKOUT",
            actions: [viewAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            workoutReminderCategory,
            upcomingWorkoutCategory
        ])
    }
    
    // MARK: - Workout Completed Notification
    
    func sendWorkoutCompletedNotification(workoutTitle: String, duration: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Workout Complete! 🎉"
        content.body = "Great job finishing \(workoutTitle) in \(formatDuration(duration))!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    // MARK: - Clear Badge
    
    func clearBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notification even when app is in foreground
        return [.banner, .sound, .badge]
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        
        Task { @MainActor in
            handleNotificationAction(actionIdentifier, userInfo: userInfo)
        }
    }
    
    @MainActor
    private func handleNotificationAction(_ actionIdentifier: String, userInfo: [AnyHashable: Any]) {
        switch actionIdentifier {
        case "START_WORKOUT":
            // Navigate to today's workout
            NotificationCenter.default.post(name: .navigateToWorkout, object: nil)
            
        case "VIEW_WORKOUT":
            if let workoutId = userInfo["workoutId"] as? String {
                NotificationCenter.default.post(
                    name: .navigateToWorkout,
                    object: nil,
                    userInfo: ["workoutId": workoutId]
                )
            }
            
        case "SNOOZE":
            // Schedule reminder for 1 hour later
            scheduleSnoozeReminder()
            
        default:
            break
        }
    }
    
    private func scheduleSnoozeReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Workout Reminder"
        content.body = "Don't forget about your workout today!"
        content.sound = .default
        content.categoryIdentifier = "WORKOUT_REMINDER"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "snoozed_reminder",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Navigation Notifications
extension Notification.Name {
    static let navigateToWorkout = Notification.Name("navigateToWorkout")
}

