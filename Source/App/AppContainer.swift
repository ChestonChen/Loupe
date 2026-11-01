//
//  AppContainer.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import UIKit

/// 组合根：整个 App 唯一一处 new 实现的地方。
@MainActor
final class AppContainer {
    let metrics: PipelineMetrics
    let pipeline: ImagePipeline
    let repository: PhotoRepository
    let feed: FeedViewModel

    private var memoryWarningToken: NSObjectProtocol?

    init() {
        let metrics = PipelineMetrics()
        let pipeline = ImagePipeline.live { event in
            Task { @MainActor in metrics.record(event) }
        }
        let repository = PhotoRepository(loader: PicsumFeedLoader())

        self.metrics = metrics
        self.pipeline = pipeline
        self.repository = repository
        self.feed = FeedViewModel(repository: repository)

        // 内存警告是 App 的生命周期事件，核心库不认识 UIApplication。
        // App 决定「何时清」，管线提供「怎么清」。
        memoryWarningToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { await pipeline.purgeMemory() }
        }
    }

    deinit {
        if let memoryWarningToken {
            NotificationCenter.default.removeObserver(memoryWarningToken)
        }
    }
}
