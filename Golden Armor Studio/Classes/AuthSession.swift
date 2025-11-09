import Foundation
import FirebaseAuth
import FirebaseCore

private enum AuthSessionError: LocalizedError {
    case missingCredential
    case unknown

    var errorDescription: String? {
        switch self {
        case .missingCredential:
            return "No credential was returned from the provider."
        case .unknown:
            return "An unknown authentication error occurred."
        }
    }
}

final class AuthSession {
    static let shared = AuthSession()

    private var listeners: [UUID: (User?) -> Void] = [:]
    private(set) var currentUser: User? {
        didSet {
            listeners.values.forEach { $0(currentUser) }
        }
    }

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var pendingSignInCompletion: ((Result<AuthDataResult, Error>) -> Void)?

    private init() {
        configureFirebaseIfNeeded()
        print("[AuthSession] Initialized. Firebase app configured: \(FirebaseApp.app() != nil)")
        currentUser = Auth.auth().currentUser
        if let user = currentUser {
            print("[AuthSession] Existing user detected on init: \(user.uid)")
        } else {
            print("[AuthSession] No user currently signed in on init.")
        }
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            print("[AuthSession] Auth state did change listener fired. User: \(String(describing: user?.uid))")
            self?.currentUser = user
        }
        print("[AuthSession] Auth state listener registered: \(authStateHandle != nil)")
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
            print("[AuthSession] Removed auth state listener during deinit.")
        }
    }

    private func configureFirebaseIfNeeded() {
        guard FirebaseApp.app() == nil else { return }

        if let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: filePath) {
            print("[AuthSession] Configuring Firebase using GoogleService-Info.plist located at: \(filePath)")
            FirebaseApp.configure(options: options)
            return
        }

        let options = FirebaseOptions(googleAppID: "1:732128551566:ios:c75928cf35c7a7ef4a9fdf",
                                      gcmSenderID: "732128551566")
        options.apiKey = "AIzaSyCfI_l0bf1PAxzCkovZCkRnnKKJpeZA5Q4"
        options.projectID = "goldenarmorstudios"
        options.storageBucket = "goldenarmorstudios.firebasestorage.app"
        print("[AuthSession] Configuring Firebase using fallback FirebaseOptions.")
        FirebaseApp.configure(options: options)
    }

    @discardableResult
    func addListener(_ listener: @escaping (User?) -> Void) -> UUID {
        let identifier = UUID()
        listeners[identifier] = listener
        print("[AuthSession] Added listener \(identifier). Current listener count: \(listeners.count)")
        listener(currentUser)
        return identifier
    }

    func removeListener(_ identifier: UUID) {
        listeners.removeValue(forKey: identifier)
        print("[AuthSession] Removed listener \(identifier). Current listener count: \(listeners.count)")
    }

    func signInWithGitHub(completion: @escaping (Result<AuthDataResult, Error>) -> Void) {
        configureFirebaseIfNeeded()
        pendingSignInCompletion = completion
        print("[AuthSession] Starting GitHub sign-in flow.")

        let provider = OAuthProvider(providerID: "github.com")
        provider.scopes = ["read:user", "user:email"]
        provider.customParameters = ["allow_signup": "false"]
        print("[AuthSession] OAuthProvider configured with scopes: \(provider.scopes ?? []) and parameters: \(provider.customParameters ?? [:])")

        provider.getCredentialWith(nil) { [weak self] credential, error in
            guard let self = self else { return }

            if let error {
                print("[AuthSession] Failed to retrieve GitHub credential: \(error.localizedDescription)")
                self.completeSignIn(with: .failure(error))
                return
            }

            guard let credential else {
                print("[AuthSession] GitHub credential retrieval returned nil without error.")
                self.completeSignIn(with: .failure(AuthSessionError.missingCredential))
                return
            }

            print("[AuthSession] Received GitHub credential. Proceeding to Firebase signIn.")
            Auth.auth().signIn(with: credential) { result, error in
                if let error {
                    print("[AuthSession] Firebase sign-in with GitHub credential failed: \(error.localizedDescription)")
                    self.completeSignIn(with: .failure(error))
                    return
                }

                guard let result else {
                    print("[AuthSession] Firebase returned nil result and no error – treating as unknown failure.")
                    self.completeSignIn(with: .failure(AuthSessionError.unknown))
                    return
                }

                print("[AuthSession] Firebase sign-in succeeded for user: \(result.user.uid)")
                self.completeSignIn(with: .success(result))
            }
        }
    }

    private func completeSignIn(with result: Result<AuthDataResult, Error>) {
        let completion = pendingSignInCompletion
        pendingSignInCompletion = nil

        guard let completion else { return }
        switch result {
        case .success(let authResult):
            print("[AuthSession] Completing sign-in success callback for user: \(authResult.user.uid)")
        case .failure(let error):
            print("[AuthSession] Completing sign-in failure callback: \(error.localizedDescription)")
        }
        DispatchQueue.main.async {
            completion(result)
        }
    }

    func handleOpenURL(_ url: URL) -> Bool {
        configureFirebaseIfNeeded()
        let handled = Auth.auth().canHandle(url)
        print("[AuthSession] Handle open URL \(url.absoluteString) – handled: \(handled)")
        return handled
    }

    func signOut() throws {
        configureFirebaseIfNeeded()
        print("[AuthSession] Attempting sign-out for current user: \(String(describing: Auth.auth().currentUser?.uid))")
        try Auth.auth().signOut()
        print("[AuthSession] Sign-out succeeded.")
    }
}
