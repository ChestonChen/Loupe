//
//  PipelineMetrics.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import Foundation

/// 订阅管线事件、维护累计值。它不认识缓存、不参与加载。
@MainActor
final class PipelineMetrics {
    private(set) var memoryHits = 0 //缓存命中数
    private(set) var diskHits = 0 //磁盘命中数
    private(set) var networkLoads = 0 //网络下载次数
    private(set) var failures = 0 //失败次数
    private(set) var lastDecodeMS: Double = 0 //最近一次解码耗时

    var totalRequests: Int { memoryHits + diskHits + networkLoads } //总请求数

    //那边每发出一次图片请求就会产生一次事件，在这里统计
    func record(_ event: PipelineEvent) {
        switch event {
        case .memoryHit: memoryHits += 1
        case .diskHit: diskHits += 1
        case .networkLoaded: networkLoads += 1
        case let .decoded(seconds): lastDecodeMS = seconds * 1000
        case .failed: failures += 1
        }
    }

    //算百分比的数学函数
    func percent(_ hits: Int) -> String {
        guard totalRequests > 0 else { return "0%" }
        return "\(Int(Double(hits) / Double(totalRequests) * 100))%"
    }
}
