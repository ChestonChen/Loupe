//
//  TaskRegistry.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import Foundation

/// 在途请求表：去重 + 引用计数。
///
/// 多个订阅者共享同一个 Task 时，
/// 「有人取消就 cancel」会误伤其他订阅者；「没人取消」又会浪费带宽。
/// 只有计数归零才 cancel，才能同时满足两者。
///
/// 单独成 actor：这段逻辑可以脱离网络、缓存单独测。
actor TaskRegistry {
    private struct Entry {
        let task: Task<ImageResponse, Error> //正在跑的任务
        var waiters: Int //有几个调用方在等这个任务
    }

    private var entries: [String: Entry] = [:] //记录所有正在进行的请求，键是缓存键

    /// 是一个原子段。中间只要有 await，两个并发调用就会各自建一个 Task。
    /// 有就加入（计数 +1）、没有就新建
    func task(for key: String,
              make: @Sendable () -> Task<ImageResponse, Error>) -> Task<ImageResponse, Error> {
        if var entry = entries[key] {
            entry.waiters += 1
            entries[key] = entry
            print("♻️ 复用进行中的请求，waiters → \(entry.waiters)")
            return entry.task
        }
        let task = make()
        entries[key] = Entry(task: task, waiters: 1)
        return task
    }
    //订阅者减一，归零时取消任务
    func release(_ key: String) {
        guard var entry = entries[key] else { return }
        entry.waiters -= 1
        if entry.waiters <= 0 {
            entry.task.cancel()
            entries[key] = nil
        } else {
            entries[key] = entry
        }
    }

    var count: Int { entries.count }
}
