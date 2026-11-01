//
//  PhotoRepository.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//


import Foundation

/// 只负责「怎么取数据」：分页、去重、是否到底。不碰布局、不碰 UI 状态。
/// 之所以和 ViewModel 分开：这一层可以注入假的 API 做单测，ViewModel 不行。
@MainActor
final class PhotoRepository {
    private let loader: any FeedLoading
    private var page = 0 //加载到第几页
    private var seen = Set<String>() //已经看到的所有图片id
    private(set) var reachedEnd = false //是否到底

    init(loader: any FeedLoading = PicsumFeedLoader()) {
        self.loader = loader
    }

    /// 下拉刷新时把分页状态清干净，否则 page 会一直往后走
    func reset() {
        page = 0
        seen.removeAll()
        reachedEnd = false
    }
    //请求下一页
    func nextPage() async throws -> [Photo] {
        guard !reachedEnd else { return [] }
        let fetched = try await loader.page(page + 1, limit: 30)
        if fetched.isEmpty {
            reachedEnd = true
            return []
        }
        page += 1
        return fetched.filter { seen.insert($0.id).inserted }
    }
}
