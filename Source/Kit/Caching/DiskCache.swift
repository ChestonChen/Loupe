import CryptoKit
import Foundation
import os
/// 文件树 + mtime 的 LRU。
///
/// 不用 SQLite 存 blob：图片是几百 KB 的二进制，文件系统就是最合适的 KV，
/// 读写零拷贝、能直接 mmap；SQLite 存 blob 会带来写放大和 vacuum 成本。
/// 元数据（大小）从文件属性拿，够用；将来要存 ETag/命中次数再上索引表。
actor DiskCache: DataCaching {
    private let folder: URL
    private let limit: Int
    private var currentSize = 0
    private var didScan = false
    private var lastTrim = Date.distantPast
    private var storeCount = 0

    init(sizeLimit: Int = 200 * 1024 * 1024) {
        self.limit = max(1, sizeLimit)
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        folder = caches.appendingPathComponent("LoupeImages", isDirectory: true)
    }


    //取也是data
    func data(for key: String) async -> Data? {
        let file = url(for: key)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
              let data = try? Data(contentsOf: file) else { return nil }

        // 一小时内的重复读不再回写 mtime —— 否则每个命中都多一次文件系统写。
        if let modified = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) > 3600 {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        }
        return data
    }

    //存的是data不是uiimage
    func store(_ data: Data, for key: String) async {
        // 第一次写先把已有文件统计一遍；之后每次调用都是空转，见 scanIfNeeded 里的 guard
        scanIfNeeded()

        let file = url(for: key)
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)

        // 覆盖写要扣掉旧文件大小，否则 currentSize 只增不减。
        let oldSize = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        do {
            try data.write(to: file, options: .atomic)
            currentSize += data.count - oldSize
            // 设备锁屏后仍可读，但不允许在锁屏时被系统批量加密迁移
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: file.path
            )
        } catch {
            // 写失败通常是磁盘满或沙盒异常：不崩，但要能被看到
            LoupeLog.cache.error("disk write failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        // 系统会在后台清理 Caches，currentSize 会逐渐偏离真实值。
        // 每 100 次写入重扫一次，成本可忽略。
        storeCount += 1
        if storeCount % 100 == 0 {
            didScan = false
            scanIfNeeded()
        }

        trimIfNeeded()
    }

    func removeAll() async {
        try? FileManager.default.removeItem(at: folder)
        currentSize = 0
        didScan = false
    }

    private func url(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return folder
            .appendingPathComponent(String(digest.prefix(2)), isDirectory: true)
            .appendingPathComponent(digest)
    }

    private func scanIfNeeded() {
        guard !didScan else { return }
        didScan = true
        currentSize = 0
        guard let enumerator = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return }
        for case let file as URL in enumerator {
            currentSize += (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
    }

    /// 一分钟最多整理一次：调用频率和写入解耦，避免「超限后每次写都全量扫目录」。
    private func trimIfNeeded() {
        guard currentSize > limit else { return }
        let now = Date()
        guard now.timeIntervalSince(lastTrim) > 60 else { return }
        lastTrim = now

        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        guard let dirs = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys
        ) else { return }

        var files: [(url: URL, date: Date, size: Int)] = []
        for dir in dirs {
            let children = (try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: keys
            )) ?? []
            for file in children {
                let values = try? file.resourceValues(forKeys: Set(keys))
                files.append((file,
                              values?.contentModificationDate ?? .distantPast,
                              values?.fileSize ?? 0))
            }
        }

        let target = limit * 8 / 10
        var removed = 0
        for item in files.sorted(by: { $0.date < $1.date }) {
            guard currentSize > target else { break }
            try? FileManager.default.removeItem(at: item.url)
            currentSize -= item.size
            removed += 1
        }
        if removed > 0 {
            LoupeLog.cache.debug("trimmed \(removed) files, now \(self.currentSize) bytes")
        }
    }
}
