//
//  HUDView.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import UIKit

//显示屏幕右下角的debug面板，记录事件命中统计
final class HUDView: UIView {
    private let label = UILabel()
    private weak var pipeline: ImagePipeline?
    private weak var metrics: PipelineMetrics?
    private var timer: Timer?

    init(pipeline: ImagePipeline, metrics: PipelineMetrics) {
        self.pipeline = pipeline
        self.metrics = metrics
        super.init(frame: .zero)

        backgroundColor = UIColor.black.withAlphaComponent(0.65)
        layer.cornerRadius = 8

        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        ])

        // 必须加到 .common：scheduledTimer 默认进 .default，滚动时会被 RunLoop 暂停
        //每一秒统计一次
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        Task { @MainActor in await refresh() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { timer?.invalidate() }

    @MainActor
    private func refresh() async {
        guard let metrics, let pipeline else { return }
        let stats = await pipeline.stats()

        label.text = """
        内存 \(stats.memoryCost / 1024 / 1024) / \(stats.memoryLimit / 1024 / 1024) MB
        命中 内存 \(metrics.percent(metrics.memoryHits)) · 磁盘 \(metrics.percent(metrics.diskHits))
        在途 \(stats.inflight)
        解码 \(String(format: "%.1f", metrics.lastDecodeMS)) ms
        请求 \(metrics.totalRequests) 次（网络 \(metrics.networkLoads)）· 失败 \(metrics.failures)
        """
    }
}
