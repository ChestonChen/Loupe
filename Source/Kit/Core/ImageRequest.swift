import Foundation

/// 「要一张图」这件事的完整描述。
/// 描述「要哪张图、多大、多急」
public struct ImageRequest: Sendable {
    /// 缓存版本号：解码策略或缓存布局变化时升这个号，老缓存自然失效。
    public static let cacheVersion = "v1"
    public let url: URL //图片url
    public let targetPixel: Int //目标像素，解码时缩到这么大
    public let priority: TaskPriority //任务优先级

    public init(url: URL, targetPixel: Int, priority: TaskPriority = .userInitiated) {
        self.url = url
        self.targetPixel = max(1, targetPixel)
        self.priority = priority
    }
    /// 缓存键由请求派生 —— 全项目唯一的事实来源。
        public var cacheKey: String {
            "\(Self.cacheVersion)|\(url.absoluteString)|\(targetPixel)"
        }
}
