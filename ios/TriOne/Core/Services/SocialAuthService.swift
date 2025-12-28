import SwiftUI
import AuthenticationServices
import CryptoKit
import GoogleSignIn

// MARK: - Social Auth Service
@MainActor
class SocialAuthService: NSObject, ObservableObject {
    static let shared = SocialAuthService()
    
    @Published var isAuthenticating = false
    @Published var errorMessage: String?
    
    // Store the current nonce for Apple Sign In verification
    private var currentNonce: String?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Apple Sign In
    
    /// Note: Sign in with Apple requires a paid Apple Developer Program membership ($99/year)
    /// For development with a free account, use Google Sign-In or Dev Mode instead
    var isAppleSignInAvailable: Bool {
        // This will be true when running with a paid developer account
        // For now, we'll check if the entitlement is properly configured
        #if DEBUG
        // In debug, show message about needing paid account
        return false
        #else
        return true
        #endif
    }
    
    func signInWithApple() {
        guard isAppleSignInAvailable else {
            errorMessage = "Sign in with Apple requires a paid Apple Developer account ($99/year). Use Google or Dev Mode instead."
            return
        }
        
        isAuthenticating = true
        errorMessage = nil
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() {
        isAuthenticating = true
        errorMessage = nil
        
        // Get the presenting view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to get root view controller"
            isAuthenticating = false
            return
        }
        
        // Find the topmost presented view controller
        var presentingVC = rootViewController
        while let presented = presentingVC.presentedViewController {
            presentingVC = presented
        }
        
        // Perform Google Sign In
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { [weak self] result, error in
            Task { @MainActor in
                self?.handleGoogleSignInResult(result: result, error: error)
            }
        }
    }
    
    @MainActor
    private func handleGoogleSignInResult(result: GIDSignInResult?, error: Error?) {
        isAuthenticating = false
        
        if let error = error {
            // Check if user cancelled
            if (error as NSError).code == GIDSignInError.canceled.rawValue {
                // User cancelled, don't show error
                return
            }
            errorMessage = error.localizedDescription
            return
        }
        
        guard let result = result else {
            errorMessage = "No result from Google Sign-In"
            return
        }
        
        let user = result.user
        let userID = user.userID ?? UUID().uuidString
        let email = user.profile?.email
        let displayName = user.profile?.name
        
        print("Google Sign In Success:")
        print("  User ID: \(userID)")
        print("  Email: \(email ?? "not provided")")
        print("  Name: \(displayName ?? "not provided")")
        
        // Create user via AuthService (legacy method for now)
        AuthService.shared.signInWithGoogleLegacy(
            userID: userID,
            email: email,
            displayName: displayName
        )
        
        HapticService.shared.success()
    }
    
    // MARK: - Nonce Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension SocialAuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            handleAppleAuthorization(authorization)
        }
    }
    
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            isAuthenticating = false
            
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    // User canceled, don't show error
                    break
                case .failed:
                    errorMessage = "Sign in failed. Please try again."
                case .invalidResponse:
                    errorMessage = "Invalid response from Apple."
                case .notHandled:
                    errorMessage = "Sign in request not handled."
                case .unknown:
                    errorMessage = "An unknown error occurred."
                case .notInteractive:
                    errorMessage = "Sign in requires interaction."
                @unknown default:
                    errorMessage = "Sign in failed."
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    @MainActor
    private func handleAppleAuthorization(_ authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Invalid credential type"
            isAuthenticating = false
            return
        }
        
        guard let nonce = currentNonce else {
            errorMessage = "Invalid state: no nonce"
            isAuthenticating = false
            return
        }
        
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            errorMessage = "Unable to get identity token"
            isAuthenticating = false
            return
        }
        
        // Get user info
        let userID = appleIDCredential.user
        let email = appleIDCredential.email
        let fullName = appleIDCredential.fullName
        
        let firstName = fullName?.givenName
        let lastName = fullName?.familyName
        
        print("Apple Sign In Success:")
        print("  User ID: \(userID)")
        print("  Email: \(email ?? "not provided")")
        print("  Name: \(firstName ?? "") \(lastName ?? "")")
        
        // In production, send idTokenString to your backend/Supabase for verification
        // For now, create a local user in dev mode
        
        Task {
            await createUserFromApple(
                userID: userID,
                email: email,
                firstName: firstName,
                lastName: lastName,
                idToken: idTokenString,
                nonce: nonce
            )
        }
    }
    
    @MainActor
    private func createUserFromApple(
        userID: String,
        email: String?,
        firstName: String?,
        lastName: String?,
        idToken: String,
        nonce: String
    ) async {
        // In production, you would:
        // 1. Send the idToken to Supabase: supabase.auth.signInWithIdToken(provider: .apple, idToken: idToken)
        // 2. Or send to your backend for verification
        
        // For now, create a user via the auth service (similar to dev mode)
        let authService = AuthService.shared
        
        // Create user with Apple credentials (legacy method for now)
        authService.signInWithAppleLegacy(
            userID: userID,
            email: email,
            firstName: firstName,
            lastName: lastName
        )
        
        isAuthenticating = false
        HapticService.shared.success()
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension SocialAuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the key window on main actor
        return MainActor.assumeIsolated {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first else {
                return UIWindow()
            }
            return window
        }
    }
}

// MARK: - Sign in with Apple Button View
struct SignInWithAppleButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.title3)
                
                Text("Apple")
                    .fontWeight(.medium)
            }
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Google Sign In Button View
struct SignInWithGoogleButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Google "G" logo colors approximation
                Image(systemName: "g.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                
                Text("Google")
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }
}

