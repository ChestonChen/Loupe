//
//  ImagePipeline+Live.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import Foundation

/// Kit 自己的组合根：唯一一处把「默认实现」装配起来的地方。
extension ImagePipeline {
    public static func live(configuration: PipelineConfiguration = .init(),
                            onEvent: (@Sendable (PipelineEvent) -> Void)? = nil) -> ImagePipeline {
        let memoryLimit = configuration.memoryCostLimit > 0
            ? configuration.memoryCostLimit
            : MemoryBudget.recommended()

        return ImagePipeline(memory: MemoryCache(costLimit: memoryLimit),
                             disk: DiskCache(sizeLimit: configuration.diskSizeLimit),
                             decoder: ImageIODecoder(),
                             loader: URLSessionDataLoader(),
                             configuration: configuration,
                             onEvent: onEvent)
    }
}
