//
//  AppDelegate.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/30.
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    //启动完成时调用
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        true
    }

    //系统要创建一个新场景时调用
    //场景的配置信息
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration",
                                                 sessionRole: connectingSceneSession.role)
        // 纯代码工程必须显式指定场景代理类。
        // 自动生成的 Info.plist 里没有 UIApplicationSceneManifest 的 delegate 配置，
        // 不写这一行 SceneDelegate 永远不会被调用 —— 表现就是启动后全黑。
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
//点图标
//  ↓
//① 系统读 Info.plist，知道「这个 App 用场景（scene）机制」
//  ↓
//② 系统创建 AppDelegate（@main 标的那一个）
//  ↓
//③ 系统调 didFinishLaunchingWithOptions —— App 活过来的第一刻
//  ↓
//④ 系统要建一个「场景」（就是窗口），问 AppDelegate：
//     「用哪个配置？」→ configurationForConnecting
//  ↓
//⑤ 配置里说了 delegateClass = SceneDelegate
//     → 系统才去创建 SceneDelegate
//  ↓
//⑥ SceneDelegate 里创建 UIWindow、设根控制器  ← 步骤 7 才干这事
