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
        } catch {
            print("No existing session: \(error)")
        }
        
        isInitialized = true
        
        // Listen for auth changes
        for await (event, session) in client.auth.authStateChanges {
            print("Auth state changed: \(event)")
            self.session = session
            
            // Notify AuthService of changes
            if let session = session {
                await AuthService.shared.handleSessionChange(session: session)
            } else {
                await AuthService.shared.handleSignOut()
            }
        }
    }
    
    // MARK: - Auth Methods
    
    func signUp(email: String, password: String) async throws -> Session {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )
        
        guard let session = response.session else {
            throw SupabaseError.noSession
        }
        
        return session
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
    
    var errorDescription: String? {
        switch self {
        case .noSession:
            return "No session returned from authentication"
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

