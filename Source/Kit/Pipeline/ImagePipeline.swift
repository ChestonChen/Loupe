//
//  ImagePipeline.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/30.
//

import Foundation
import UIKit
import os
//图片加载入口
final class ImagePipeline: Sendable {
    
    //记录流水线状态
    public struct Stats: Sendable {
            public let memoryCost: Int
            public let memoryLimit: Int
            public let inflight: Int //现在有几个请求正在处理中，还没返回
        }
    private let loader: any DataLoading //下载器
    private let decoder: any ImageDecoding //解码器
    private let memory: any ImageCaching
    private let disk: any DataCaching //磁盘缓存，存的是原始字节
    private let onEvent: (@Sendable (PipelineEvent) -> Void)?
    private let registry: TaskRegistry
    private let downloadGate: AsyncSemaphore
    private let decodeGate: AsyncSemaphore //下载并发控制
    private let maxRetryCount: Int
    
    public init(memory: any ImageCaching,
                    disk: any DataCaching,
                    decoder: any ImageDecoding,
                    loader: any DataLoading,
                    configuration: PipelineConfiguration = .init(),
                    onEvent: (@Sendable (PipelineEvent) -> Void)? = nil) {
            self.memory = memory
            self.disk = disk
            self.decoder = decoder
            self.loader = loader
            self.onEvent = onEvent
            self.registry = TaskRegistry()
            self.downloadGate = AsyncSemaphore(limit: configuration.maxConcurrentDownloads)
            self.decodeGate = AsyncSemaphore(limit: configuration.maxConcurrentDecodes)
            self.maxRetryCount = configuration.maxRetryCount
        }


    public func image(for request: ImageRequest) async throws -> ImageResponse {
        let key = request.cacheKey

                if let cached = await memory.image(for: key) {
                    onEvent?(.memoryHit)
                    return ImageResponse(image: cached, source: .memory)
                }
        //从缓存找不到再真正下载数据
        let task = await registry.task(for: key) { [self] in
                   Task.detached(priority: request.priority) { [self] in
                       try await load(request)
                   }
               }

               do {
                   let response = try await task.value
                   await registry.release(key)
                   return response
               } catch {
                   // 无论失败还是被取消，都要把引用计数还回去
                   await registry.release(key)
                   throw Self.normalize(error)
               }
    }
    public func stats() async -> Stats {
            Stats(memoryCost: await memory.cost,
                  memoryLimit: memory.costLimit,
                  inflight: await registry.count)
        }
    //真正的加载逻辑
    private func load(_ request: ImageRequest) async throws -> ImageResponse {
            let key = request.cacheKey

            // 进 Task 之后再查一次：排队期间可能已经被别的请求填上了
            if let cached = await memory.image(for: key) {
                onEvent?(.memoryHit)
                return ImageResponse(image: cached, source: .memory)
            }

            let source: ImageSource
            let payload: Data

            if let cachedData = await disk.data(for: key) {
                onEvent?(.diskHit)
                source = .disk
                payload = cachedData
            } else {
                // fetchData 返回的是非可选的 Data：拿不到会抛错，不会返回 nil
                let fetched = try await fetchData(request)
                await disk.store(fetched, for: key)
                onEvent?(.networkLoaded(bytes: fetched.count))
                source = .network
                payload = fetched
            }

            let started = CFAbsoluteTimeGetCurrent()
            let image = try await decodeGate.withPermit { [decoder] in
                decoder.decode(payload, request: request)
            }
            let duration = CFAbsoluteTimeGetCurrent() - started

            guard let image else {
                onEvent?(.failed(.decodeFailed))
                throw ImageLoadingError.decodeFailed
            }

            await memory.store(image, for: key)
            onEvent?(.decoded(seconds: duration))
            return ImageResponse(image: image, source: source)
        }

        /// 只在「可重试」时再来一次：4xx 和取消都不重试，5xx / 网络抖动重试一次。
        /// 没有做无限重试，是为了避免离线时把电量烧光。
        private func fetchData(_ request: ImageRequest) async throws -> Data {
            var attempt = 0
            while true {
                do {
                    return try await downloadGate.withPermit { [loader] in
                        try await loader.data(for: request)
                    }
                } catch {
                    let mapped = Self.normalize(error)
                    guard mapped.isRetryable, attempt < maxRetryCount else {
                        LoupeLog.pipeline.debug("download failed: \(String(describing: mapped), privacy: .public)")
                        // 重试用尽才算失败：否则 HUD 的「失败」永远是 0，网络错误被吞掉。
                        // 取消不算失败（是用户自己划走的），不亮红。
                        if case .cancelled = mapped {} else { onEvent?(.failed(mapped)) }
                        throw mapped
                    }
                    attempt += 1
                    // 取消时 sleep 会抛 CancellationError，直接冒泡 —— 不能吞掉再发一次
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
            }
        }

        /// 内存警告时由 App 层调用。谁决定清理是策略，怎么清理是机制。
        public func purgeMemory() async {
            await memory.removeAll()
        }

        private static func normalize(_ error: Error) -> ImageLoadingError {
            if error is CancellationError { return .cancelled }
            // URLSession 被取消时抛的是 URLError(.cancelled)，不是 CancellationError
            if let urlError = error as? URLError, urlError.code == .cancelled { return .cancelled }
            if let known = error as? ImageLoadingError { return known }
            return .transport(error.localizedDescription)
        }
}
