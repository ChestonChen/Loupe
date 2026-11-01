//
//  MemoryCache.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import UIKit

/// 按解码后字节计费的 LRU。
/// 不用 NSCache：NSCache 的淘汰时机不可控（系统内存压力时才清），
/// 命中率不可预期，也没法做「按字节计费」的确定性测试。
/// actor保证线程安全
actor MemoryCache: ImageCaching {
    private struct Entry {
        let image: UIImage
        let cost: Int
    }

    private var entries: [String: Entry] = [:] //存缓存的字典 key - 图片+对应字节
    private var order: [String] = [] //记录使用顺序，末尾是最近用的
    private var totalCost = 0 //当前字节
    private let limit: Int //上限

    init(costLimit: Int = 64 * 1024 * 1024) { //默认给64MB 除非显示传更大的，最小1MB
        self.limit = max(1, costLimit)
    }

    var cost: Int { totalCost }
    nonisolated var costLimit: Int { limit } //上限的访问不需要线程安全，只读

    func image(for key: String) -> UIImage? {
        guard let entry = entries[key] else { return nil }
        //更新使用顺序
        touch(key)
        return entry.image
    }

    func store(_ image: UIImage, for key: String) {
        if let old = entries.removeValue(forKey: key) {
            totalCost -= old.cost //缓存中有先扣再加
        }
        let cost = image.memoryCost //算多大字节
        entries[key] = Entry(image: image, cost: cost)
        totalCost += cost //加回来
        touch(key)
        evictIfNeeded() //检测是否超了 超了就删
    }

    func removeAll() {
        entries.removeAll()
        order.removeAll()
        totalCost = 0
    }

    private func touch(_ key: String) {
        if let position = order.firstIndex(of: key) {
            order.remove(at: position)
        }
        order.append(key)
    }

    private func evictIfNeeded() {
        while totalCost > limit, let oldest = order.first {
            order.removeFirst()
            if let entry = entries.removeValue(forKey: oldest) {
                totalCost -= entry.cost
            }
        }
    }
}

extension UIImage {
    /// 真实占用：含行对齐，不是 width * height * 4。
    var memoryCost: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
