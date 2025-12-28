import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var socialAuth = SocialAuthService.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var isValid: Bool {
        !email.isEmpty && 
        password.count >= 8 && 
        password == confirmPassword
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                formSection
                termsText
                errorSection
                createAccountButton
                dividerSection
                socialLoginSection
                loginLinkSection
                devModeButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Theme.text)
            
            Text("Start your triathlon journey today")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.bottom, 32)
    }
    
    private var formSection: some View {
        VStack(spacing: 20) {
            emailField
            passwordField
            confirmPasswordField
        }
    }
    
    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Theme.text)
            
            TextField("your@email.com", text: $email)
                .textInputField()
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
        }
    }
    
    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Theme.text)
            
            HStack {
                if showPassword {
                    TextField("At least 8 characters", text: $password)
                } else {
                    SecureField("At least 8 characters", text: $password)
                }
                
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .textInputField()
        }
    }
    
    private var confirmPasswordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Confirm Password")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Theme.text)
            
            SecureField("Repeat your password", text: $confirmPassword)
                .textInputField()
        }
    }
    
    private var termsText: some View {
        Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
            .font(.subheadline)
            .foregroundStyle(Theme.textMuted)
            .multilineTextAlignment(.center)
            .padding(.top, 24)
    }
    
    @ViewBuilder
    private var errorSection: some View {
        if let error = errorMessage {
            Text(error)
                .font(.subheadline)
                .foregroundStyle(Theme.error)
                .padding(.top, 16)
        }
    }
    
    private var createAccountButton: some View {
        Button {
            handleRegister()
        } label: {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                Text("Create Account")
                    .primaryButtonStyle()
            }
        }
        .disabled(isLoading || !isValid)
        .opacity(isValid ? 1 : 0.5)
        .padding(.top, 24)
    }
    
    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
            
            Text("or continue with")
                .font(.subheadline)
                .foregroundStyle(Theme.textMuted)
                .padding(.horizontal, 16)
            
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
        }
        .padding(.vertical, 32)
    }
    
    private var socialLoginSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                SignInWithGoogleButton {
                    socialAuth.signInWithGoogle()
                }
                
                SignInWithAppleButton {
                    socialAuth.signInWithApple()
                }
            }
            .disabled(socialAuth.isAuthenticating)
            .opacity(socialAuth.isAuthenticating ? 0.6 : 1)
            
            if socialAuth.isAuthenticating {
                ProgressView()
                    .padding(.top, 8)
            }
            
            if let socialError = socialAuth.errorMessage {
                Text(socialError)
                    .font(.caption)
                    .foregroundStyle(Theme.error)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }
    
    private var loginLinkSection: some View {
        HStack {
            Text("Already have an account?")
                .foregroundStyle(Theme.textSecondary)
            
            NavigationLink(destination: LoginView()) {
                Text("Sign In")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.primary)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }
    
    private var devModeButton: some View {
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
        .padding(.top, 24)
    }
    
    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "arrow.left")
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.text)
                .frame(width: 40, height: 40)
                .background(Theme.backgroundSecondary)
                .clipShape(Circle())
        }
    }
    
    // MARK: - Actions
    
    private func handleRegister() {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.signUp(email: email, password: password)
                // Success - navigation will happen automatically via auth state change
            } catch {
                await MainActor.run {
                    isLoading = false
                    // Show detailed error message
                    if let supabaseError = error as? SupabaseError {
                        errorMessage = supabaseError.localizedDescription
                    } else {
                        errorMessage = "Failed to create account: \(error.localizedDescription)"
                    }
                    print("❌ Sign-up error: \(error)")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
    }
    .environmentObject(AuthService.shared)
}
