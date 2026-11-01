//
//  URLSessionDataLoader.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/30.
//

import Foundation

//用URLSession 实现的下载器
public struct URLSessionDataLoader: DataLoading {
    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session {
            //新建会话
            self.session = session
            return
        }
        let configuration = URLSessionConfiguration.default
        // 显式关掉 HTTP 缓存：我们自己按「URL + 目标尺寸」存，两层都留会双写。
        //我们自己有两层缓存（内存 + 磁盘），键是「URL + 目标尺寸」。如果 URLSession 也按 URL 存一份，同一张图会被存两遍，而且它不知道尺寸——你按 540 请求，它给你 1080 的缓存，图就糊了
        configuration.urlCache = nil
        //即使有缓存也不用，永远真发请求
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        //单次请求超时20s 默认60s
        configuration.timeoutIntervalForRequest = 20
        //对同一个域名最多 6 条并发连接
        configuration.httpMaximumConnectionsPerHost = 6
        self.session = URLSession(configuration: configuration)
    }
//    URLSessionConfiguration   配置（超时、缓存、连接数）
//            ↓ 用它创建
//        URLSession            会话（相当于一个"浏览器"）
//            ↓ 每次请求
//        URLRequest            一次具体请求（URL + 请求头）
//            ↓ 发出去
//    (Data, URLResponse)       回来的字节 + 响应

    //遵循的那个网络下载的协议方法实现
    public func data(for request: ImageRequest) async throws -> Data {
        var urlRequest = URLRequest(url: request.url)
        //加一个请求头，User-Agent 是告诉服务器「我是谁」
        urlRequest.setValue("Loupe/2.0", forHTTPHeaderField: "User-Agent")
        //发请求 → 等响应 → 收完整个 body → 返回
        // Data          响应体字节
        // URLResponse   响应元信息（状态码、头、最终 URL）
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw ImageLoadingError.badURL
        }
        //保证状态码正确
        guard (200..<300).contains(http.statusCode) else {
            throw ImageLoadingError.http(http.statusCode)
        }
        return data//照片文件的原始字节
    }
}
