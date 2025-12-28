import SwiftUI

enum Theme {
    // Primary brand color
    static let primary = Color(hex: "71c7ec")
    static let primaryDark = Color(hex: "4BA3C7")
    
    // Backgrounds
    static let background = Color.white
    static let backgroundSecondary = Color(hex: "F9FAFB")
    static let activeWorkoutBackground = Color.black
    
    // Text
    static let text = Color(hex: "111827")
    static let textSecondary = Color(hex: "6B7280")
    static let textMuted = Color(hex: "9CA3AF")
    
    // Status
    static let success = Color(hex: "22C55E")
    static let warning = Color(hex: "F59E0B")
    static let error = Color(hex: "EF4444")
    
    // Workout type colors
    static let swim = Color(hex: "0EA5E9")
    static let bike = Color(hex: "F97316")
    static let run = Color(hex: "22C55E")
    static let strength = Color(hex: "8B5CF6")
    static let brick = Color(hex: "EC4899")
    
    // Border
    static let border = Color(hex: "E5E7EB")
    
    // Gradients
    static let primaryGradient = LinearGradient(
        colors: [primary, primaryDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Constants
enum Constants {
    static let trialDurationDays = 14
    
    enum RaceDistance: String, CaseIterable, Codable {
        case sprint = "sprint"
        case olympic = "olympic"
        case halfIronman = "half_ironman"
        case fullIronman = "full_ironman"
        
        var displayName: String {
            switch self {
            case .sprint: return "Sprint"
            case .olympic: return "Olympic"
            case .halfIronman: return "70.3 / Half"
            case .fullIronman: return "140.6 / Full"
            }
        }
        
        var distances: (swim: Int, bike: Int, run: Int) {
            switch self {
            case .sprint: return (750, 20_000, 5_000)
            case .olympic: return (1_500, 40_000, 10_000)
            case .halfIronman: return (1_930, 90_000, 21_100)
            case .fullIronman: return (3_860, 180_000, 42_200)
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.primary)
            .cornerRadius(12)
    }
    
    func secondaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(Theme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
    
    func cardStyle() -> some View {
        self
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

