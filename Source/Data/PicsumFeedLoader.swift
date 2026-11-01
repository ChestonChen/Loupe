//
//  PicsumFeedLoader.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import Foundation

/// Picsum 的实现。协议在上层（FeedLoading），这里只是其中一个实现。
/// 拼 URL、发请求、解 JSON
struct PicsumFeedLoader: FeedLoading {
    func page(_ index: Int, limit: Int = 30) async throws -> [Photo] {
        var components = URLComponents(string: "https://picsum.photos/v2/list")!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(index)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([Photo].self, from: data)
    }
}
