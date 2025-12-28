import Foundation
import Supabase
import Auth

/// Singleton service that manages the Supabase client
@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    @Published var session: Session?
    @Published var isInitialized = false
    
    private init() {
        // Initialize Supabase client
        // Note: The deprecation warning about initial session can be ignored for now
        // The SDK will handle session emission correctly
        client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
        
        // Listen for auth state changes
        Task {
            await setupAuthListener()
        }
    }
    
    // MARK: - Auth State
    
    private func setupAuthListener() async {
        // Get initial session
        do {
            session = try await client.auth.session
            // Check if session is expired (new behavior requirement)
            if let session = session, session.isExpired {
                print("⚠️ Initial session is expired, clearing...")
                self.session = nil
                try? await client.auth.signOut()
            }
        } catch {
            print("No existing session: \(error)")
        }
        
        isInitialized = true
        
        // Listen for auth changes
        for await (event, session) in client.auth.authStateChanges {
            print("Auth state changed: \(event)")
            
            // Check if session is expired before using it
            if let session = session {
                if session.isExpired {
                    print("⚠️ Session expired, signing out...")
                    self.session = nil
                    try? await client.auth.signOut()
                    await AuthService.shared.handleSignOut()
                } else {
                    self.session = session
                    await AuthService.shared.handleSessionChange(session: session)
                }
            } else {
                self.session = nil
                await AuthService.shared.handleSignOut()
            }
        }
    }
    
    // MARK: - Auth Methods
    
    func signUp(email: String, password: String) async throws -> Session {
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password
            )
            
            // Check if email confirmation is required
            if let session = response.session {
                return session
            } else {
                // If no session, email confirmation might be required
                // Check if user was created
                if response.user != nil {
                    throw SupabaseError.emailConfirmationRequired
                } else {
                    throw SupabaseError.noSession
                }
            }
        } catch {
            // Re-throw with more context
            if let supabaseError = error as? SupabaseError {
                throw supabaseError
            }
            
            // Wrap other errors with more context
            print("❌ Supabase sign-up error: \(error)")
            if let nsError = error as NSError? {
                print("   Error domain: \(nsError.domain)")
                print("   Error code: \(nsError.code)")
                print("   Error description: \(nsError.localizedDescription)")
                if let userInfo = nsError.userInfo as? [String: Any] {
                    print("   User info: \(userInfo)")
                }
            }
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws -> Session {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )
        
        return session
    }
    
    func signInWithApple(idToken: String, nonce: String) async throws -> Session {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        
        return session
    }
    
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> Session {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )
        
        return session
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }
    
    // MARK: - Token
    
    var accessToken: String? {
        session?.accessToken
    }
    
    var currentUserId: String? {
        session?.user.id.uuidString
    }
}


enum SupabaseError: LocalizedError {
    case noSession
    case notAuthenticated
    case invalidResponse
    case emailConfirmationRequired
    
    var errorDescription: String? {
        switch self {
        case .noSession:
            return "No session returned from authentication. Please check your Supabase configuration."
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .invalidResponse:
            return "Invalid response from server"
        case .emailConfirmationRequired:
            return "Please check your email to confirm your account. Email confirmation may be required in your Supabase settings."
        }
    }
}

