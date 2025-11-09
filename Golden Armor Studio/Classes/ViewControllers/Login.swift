import UIKit
import FirebaseAuth

@objcMembers
final class Login: UIViewController {
    private let backgroundVideoView = UIView()
    private let signInButton = UIButton(type: .system)
    private let signOutButton = UIButton(type: .system)

    private var authListenerToken: UUID?
    private var hasPresentedNews = false
    private var shouldNavigateToNewsAfterAppear = false

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[LoginVC] viewDidLoad invoked.")
        configureViews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        Videoplayer.updateLayout(for: backgroundVideoView)
        observeAuthState()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("[LoginVC] viewDidDisappear. isMovingFromParent: \(isMovingFromParent), isBeingDismissed: \(isBeingDismissed)")
        if (isMovingFromParent || isBeingDismissed),
           let token = authListenerToken {
            AuthSession.shared.removeListener(token)
            authListenerToken = nil
        }

        if isMovingFromParent || isBeingDismissed {
            Videoplayer.stopVideo(in: backgroundVideoView)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if shouldNavigateToNewsAfterAppear {
            shouldNavigateToNewsAfterAppear = false
            print("[LoginVC] viewDidAppear triggered pending navigation to News.")
            navigateToNewsIfNeeded()
        }
    }

    private func configureViews() {
        view.backgroundColor = .systemBackground

        backgroundVideoView.translatesAutoresizingMaskIntoConstraints = false
        backgroundVideoView.isUserInteractionEnabled = false
        view.insertSubview(backgroundVideoView, at: 0)
        NSLayoutConstraint.activate([
            backgroundVideoView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundVideoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundVideoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundVideoView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        signInButton.setTitle("Sign In with GitHub", for: .normal)
        signInButton.addTarget(self, action: #selector(handleSignInTapped), for: .touchUpInside)

        signOutButton.setTitle("Sign Out", for: .normal)
        signOutButton.addTarget(self, action: #selector(handleSignOutTapped), for: .touchUpInside)
        signOutButton.isHidden = true

        if #available(iOS 15.0, *) {
            signInButton.configuration = .filled()
            signInButton.configuration?.cornerStyle = .medium

            signOutButton.configuration = .borderedProminent()
            signOutButton.configuration?.cornerStyle = .medium
        }

        let stack = UIStackView(arrangedSubviews: [signInButton, signOutButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill

        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])

        Videoplayer.playVideo(resourcePath: "Videos/website background - login.mov", in: backgroundVideoView)
    }

    private func observeAuthState() {
        print("[LoginVC] Registering auth state listener.")
        authListenerToken = AuthSession.shared.addListener { [weak self] user in
            print("[LoginVC] Auth state listener callback on LoginVC with user: \(String(describing: user?.uid))")
            self?.updateUI(for: user)
        }
    }

    private func updateUI(for user: User?) {
        if let user = user {
            print("[LoginVC] Updating UI for signed-in user: \(user.uid)")
            signInButton.isHidden = true
            signOutButton.isHidden = false
            if view.window != nil {
                navigateToNewsIfNeeded()
            } else {
                shouldNavigateToNewsAfterAppear = true
                print("[LoginVC] Deferring navigation until view is in window hierarchy.")
            }
        } else {
            print("[LoginVC] Updating UI for signed-out state.")
            signInButton.isHidden = false
            signOutButton.isHidden = true
            hasPresentedNews = false
            shouldNavigateToNewsAfterAppear = false
        }
    }

    @objc
    private func handleSignInTapped() {
        print("[LoginVC] Sign-in button tapped.")
        AuthSession.shared.signInWithGitHub { [weak self] result in
            guard let self else { return }
            if case .failure(let error) = result {
                print("[LoginVC] GitHub sign-in flow returned failure: \(error.localizedDescription)")
                self.presentAlert(title: "GitHub Login Failed", message: error.localizedDescription)
            } else {
                print("[LoginVC] GitHub sign-in flow reported success.")
            }
        }
    }

    @objc
    private func handleSignOutTapped() {
        print("[LoginVC] Sign-out button tapped.")
        do {
            try AuthSession.shared.signOut()
            print("[LoginVC] Sign-out completed without throwing.")
        } catch {
            print("[LoginVC] Sign-out failed with error: \(error.localizedDescription)")
            presentAlert(title: "Sign Out Failed", message: error.localizedDescription)
        }
    }

    private func navigateToNewsIfNeeded() {
        guard !hasPresentedNews else { return }
        print("[LoginVC] Navigating to News view controller.")
        hasPresentedNews = true

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let newsViewController = storyboard.instantiateViewController(withIdentifier: "News") as? News else {
            assertionFailure("News storyboard setup is missing")
            print("[LoginVC] Failed to instantiate NewsViewController from storyboard.")
            hasPresentedNews = false
            return
        }

        if let navigationController {
            navigationController.pushViewController(newsViewController, animated: true)
            print("[LoginVC] Pushed NewsViewController onto navigation stack.")
            return
        }

        if let windowScene = view.window?.windowScene,
           let sceneDelegate = windowScene.delegate as? SceneDelegate,
           let window = sceneDelegate.window {
            let navigationController = UINavigationController(rootViewController: newsViewController)
            navigationController.modalPresentationStyle = .fullScreen
            window.rootViewController = navigationController
            window.makeKeyAndVisible()
            print("[LoginVC] Replaced rootViewController with News inside UINavigationController.")
            return
        }

        newsViewController.modalPresentationStyle = .fullScreen
        present(newsViewController, animated: true)
        print("[LoginVC] Presented NewsViewController modally as fallback.")
    }

    private func presentAlert(title: String, message: String) {
        print("[LoginVC] Presenting alert titled '\(title)' with message: \(message)")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
