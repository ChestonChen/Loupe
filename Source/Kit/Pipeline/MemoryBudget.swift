//
//  MemoryBudget.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import Foundation
import os

/// 内存缓存该开多大，不该是写死的 64MB。
enum MemoryBudget {
    /// 取「当前可用内存」的 1/8，夹在 32MB ~ 192MB 之间。
    /// 物理内存大的机器并不代表此刻能给多少。`os_proc_available_memory` 是系统给的实时值。
    static func recommended() -> Int {
        let available = Int(os_proc_available_memory())
        guard available > 0 else { return 64 * 1024 * 1024 }
        let target = available / 8
        return min(max(target, 32 * 1024 * 1024), 192 * 1024 * 1024)
    }
}
