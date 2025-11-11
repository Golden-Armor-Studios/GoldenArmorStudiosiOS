import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let targetWindow: UIWindow
        if let existingWindow = window {
            targetWindow = existingWindow
        } else {
            let newWindow = UIWindow(windowScene: windowScene)
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let initialController = storyboard.instantiateInitialViewController() ?? UIViewController()
            let navigationController = UINavigationController(rootViewController: initialController)
            navigationController.navigationBar.prefersLargeTitles = false
            newWindow.rootViewController = navigationController
            window = newWindow
            targetWindow = newWindow
        }

        let frame = windowScene.screen.bounds
        print("[SceneDelegate] windowScene screen bounds: \(frame)")
        targetWindow.frame = frame
        targetWindow.backgroundColor = .black
        targetWindow.makeKeyAndVisible()

        if let urlContext = connectionOptions.urlContexts.first {
            _ = AuthSession.shared.handleOpenURL(urlContext.url)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Restart any tasks that were paused.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Sent when the scene will move from an active state to an inactive state.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        if AuthSession.shared.handleOpenURL(url) {
            return
        }
        // Handle other deep-link URLs here if necessary.
    }
}
