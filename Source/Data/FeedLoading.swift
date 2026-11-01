//
//  FeedLoading.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import Foundation

/// 列表数据的抽象。
///
/// 有了它，PhotoRepository 可以对着假数据测「第二页为空是否停止请求」。
protocol FeedLoading: Sendable {
    func page(_ index: Int, limit: Int) async throws -> [Photo]
}
