import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var socialAuth = SocialAuthService.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                formSection
                errorSection
                signInButton
                dividerSection
                socialLoginSection
                registerLinkSection
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
            Text("Welcome back")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Theme.text)
            
            Text("Sign in to continue your training")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.bottom, 32)
    }
    
    private var formSection: some View {
        VStack(spacing: 20) {
            emailField
            passwordField
            forgotPasswordLink
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
                    TextField("••••••••", text: $password)
                } else {
                    SecureField("••••••••", text: $password)
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
    
    @State private var showForgotPassword = false
    @State private var resetEmail = ""
    @State private var resetSent = false
    
    private var forgotPasswordLink: some View {
        HStack {
            Spacer()
            Button("Forgot password?") {
                resetEmail = email
                showForgotPassword = true
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(Theme.primary)
        }
        .alert("Reset Password", isPresented: $showForgotPassword) {
            TextField("Email", text: $resetEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
            
            Button("Cancel", role: .cancel) {}
            Button("Send Reset Link") {
                Task {
                    do {
                        try await authService.resetPassword(email: resetEmail)
                        resetSent = true
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } message: {
            Text("Enter your email address to receive a password reset link.")
        }
        .alert("Check Your Email", isPresented: $resetSent) {
            Button("OK") {}
        } message: {
            Text("If an account exists with that email, you'll receive a password reset link.")
        }
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
    
    private var signInButton: some View {
        Button {
            handleLogin()
        } label: {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                Text("Sign In")
                    .primaryButtonStyle()
            }
        }
        .disabled(isLoading || email.isEmpty || password.isEmpty)
        .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1)
        .padding(.top, 32)
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
    
    private var registerLinkSection: some View {
        HStack {
            Text("Don't have an account?")
                .foregroundStyle(Theme.textSecondary)
            
            NavigationLink(destination: RegisterView()) {
                Text("Sign Up")
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
    
    private func handleLogin() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Text Field Modifier
extension View {
    func textInputField() -> some View {
        self
            .padding(16)
            .background(Theme.backgroundSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
    .environmentObject(AuthService.shared)
}
