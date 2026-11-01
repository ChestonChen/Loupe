//
//  PipelineConfiguration.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import Foundation

public struct PipelineConfiguration: Sendable {
    /// 同时下载数。默认 4：手机网络下再高只会让每张图都变慢。
    public var maxConcurrentDownloads: Int
    /// 同时解码数。默认 3：按 CPU 核数的一半估，留给主线程渲染。
    public var maxConcurrentDecodes: Int
    /// 内存缓存上限。传 0 表示按当前可用内存自动算
    public var memoryCostLimit: Int
    public var diskSizeLimit: Int
    /// 可重试错误的重试次数。0 = 不重试。
    public var maxRetryCount: Int

    public init(maxConcurrentDownloads: Int = 4,
                maxConcurrentDecodes: Int = 3,
                memoryCostLimit: Int = 0,
                diskSizeLimit: Int = 200 * 1024 * 1024,
                maxRetryCount: Int = 1) {
        self.maxConcurrentDownloads = max(1, maxConcurrentDownloads)
        self.maxConcurrentDecodes = max(1, maxConcurrentDecodes)
        self.memoryCostLimit = max(0, memoryCostLimit)
        self.diskSizeLimit = max(1, diskSizeLimit)
        self.maxRetryCount = max(0, maxRetryCount)
    }
}
