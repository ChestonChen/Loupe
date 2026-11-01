//
//  Untitled.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import Foundation

/// 磁盘缓存：存「原始字节」。
public protocol DataCaching: Sendable {
    func data(for key: String) async -> Data?
    func store(_ data: Data, for key: String) async
    func removeAll() async
}
