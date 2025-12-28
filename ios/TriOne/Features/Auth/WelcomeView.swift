import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showLogin = false
    @State private var showRegister = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()
                
                // Hero
                VStack(spacing: 24) {
                    // Logo
                    ZStack {
                        Circle()
                            .fill(Theme.primary.opacity(0.1))
                            .frame(width: 128, height: 128)
                        
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Theme.primary)
                    }
                    
                    VStack(spacing: 8) {
                        Text("TriOne")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(Theme.text)
                        
                        Text("Your Intelligent Triathlon Coach")
                            .font(.title3)
                            .foregroundStyle(Theme.textSecondary)
                        
                        Text("A training plan that changes when life happens.")
                            .font(.body)
                            .foregroundStyle(Theme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                
                Spacer()
                
                // CTAs
                VStack(spacing: 12) {
                    NavigationLink(destination: RegisterView()) {
                        Text("Get Started")
                            .primaryButtonStyle()
                    }
                    
                    NavigationLink(destination: LoginView()) {
                        Text("I already have an account")
                            .secondaryButtonStyle()
                    }
                    
                    // Dev Mode Button
                    Button {
                        authService.enableDevMode()
                    } label: {
                        Text("🚧 DEV: Skip Authentication")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                    .foregroundColor(.orange)
                            )
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
            .background(Color.white)
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthService.shared)
}

