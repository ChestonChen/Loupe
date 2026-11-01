//
//  DataLoading.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/30.
//

import Foundation

/// 数据加载协议。为什么抽它：单测里塞一个假实现，就能模拟 404 / 超时 / 弱网。
/// 谁能接一个请求、异步还我一段字节，谁就符合它
public protocol DataLoading: Sendable {
    //要等网络，可能会各种出错
    func data(for request: ImageRequest) async throws -> Data
}
