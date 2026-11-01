//
//  FeedViewModel.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import Foundation

/// 界面状态机。关键点：失败态会**挡住自动加载**，只允许用户手动重试。
@MainActor
final class FeedViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var photos: [Photo] = []
    private(set) var isRefreshing = false

    var onChange: (() -> Void)?

    private let repository: PhotoRepository
    private var isLoading = false
    /// 刷新时如果正好有一轮加载在跑，就等它结束后补一次
    private var needsReload = false
    /// 每次刷新 +1；加载回来发现代数变了就丢弃 —— 避免旧请求覆盖新列表
    private var generation = 0

    init(repository: PhotoRepository) {
        self.repository = repository
    }

    func aspectRatio(at index: Int) -> CGFloat {
        photos[safe: index]?.aspectRatio ?? 1
    }

    func loadFirstPage() async {
        guard photos.isEmpty, !isLoading else { return }
        await loadMore()
    }

    /// 滚到末尾附近时调用。**只有 loaded 状态才放行** ——
    /// 否则一次失败之后，reloadData 触发 willDisplay、willDisplay 又触发加载，
    /// 会形成无限重试风暴。
    func loadMoreIfNeeded(at index: Int) async {
        guard state == .loaded else { return }
        guard index >= photos.count - 6 else { return }
        await loadMore()
    }

    func retry() async {
        guard !isLoading else { return }
        state = .idle
        await loadMore()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        generation += 1
        repository.reset()
        photos.removeAll()
        state = .idle
        defer { isRefreshing = false }

        // 在途那轮的结果会被 generation 丢弃；直接调 loadMore 会被它的 isLoading 挡住，
        // 于是列表空着、状态停在 idle，再也没有东西触发加载。
        if isLoading {
            needsReload = true
        } else {
            await loadMore()
        }
    }

    private func loadMore() async {
        guard !isLoading, !repository.reachedEnd else { return }
        let currentGeneration = generation
        isLoading = true
        if photos.isEmpty { state = .loading }
        defer {
            isLoading = false
            if needsReload {
                needsReload = false
                Task { await loadMore() }
            }
        }

        do {
            let fresh = try await repository.nextPage()
            guard currentGeneration == generation else { return }
            photos.append(contentsOf: fresh)
            state = .loaded
        } catch {
            guard currentGeneration == generation else { return }
            state = .failed(Self.message(for: error))
        }
        onChange?()
    }

    private static func message(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "网络似乎断开了"
            case .timedOut:
                return "请求超时"
            default:
                break
            }
        }
        return "加载失败，请重试"
    }
}
