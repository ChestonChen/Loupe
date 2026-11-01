import UIKit

//管窗口和界面生命周期
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let container = AppContainer()
        let feed = FeedViewController(pipeline: container.pipeline,
                                      metrics: container.metrics,
                                      viewModel: container.feed)

        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = UINavigationController(rootViewController: feed)
        window.makeKeyAndVisible()
        self.window = window
    }
}
