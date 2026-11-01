//
//  AsyncSemaphore.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import Foundation

/// 不阻塞线程、且响应取消的信号量。
///
/// 不用 DispatchSemaphore：它在 async 上下文里会阻塞协作线程池。
/// 不用 OperationQueue：它不认 Task 的优先级和取消。
/// 限制并发数的信号量
actor AsyncSemaphore {
    private struct Waiter { //某个请求
        let id: UInt64 //这个排队请求的编号
        let continuation: CheckedContinuation<Void, Error> //用来唤醒这个排队请求
    }

    private var available: Int
    private var waiters: [Waiter] = [] //排队的请求
    /// 取消早于挂起时，先记下来，等挂起时立刻失败返回
    private var cancelledIDs: Set<UInt64> = [] //已取消但还没排上队的请求编号
    private var nextID: UInt64 = 0 //用来给排队的请求编号

    init(limit: Int) {
        available = max(1, limit)
    }
    //拿名额，没名额就排队
    func acquire() async throws {
        if Task.isCancelled { throw CancellationError() }
        if available > 0 {
            available -= 1
            return
        }

        let id = nextID
        nextID += 1

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if cancelledIDs.remove(id) != nil {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiters.append(Waiter(id: id, continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancelWaiting(id) }
        }
    }
    //取消某个排队请求
    private func cancelWaiting(_ id: UInt64) {
        if let index = waiters.firstIndex(where: { $0.id == id }) {
            let waiter = waiters.remove(at: index)
            waiter.continuation.resume(throwing: CancellationError())
        } else {
            // 还没挂起就先记下来，acquire 里会检查
            cancelledIDs.insert(id)
        }
    }
   // 还名额，或直接交给排队的人
    func release() {
        if waiters.isEmpty {
            available += 1
        } else {
            // 名额直接转交，避免「还回去又被抢走」的窗口
            waiters.removeFirst().continuation.resume()
        }
    }
 //一次完整的流程
    func withPermit<T>(_ body: () async throws -> T) async throws -> T {
        try await acquire()
        do {
            let result = try await body()
            await release()
            return result
        } catch {
            await release()
            throw error
        }
    }
}
