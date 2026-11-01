//
//  ImageLoadingError.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/30.
//

import Foundation

/// 分型错误：调用方要能区分「可重试」和「别重试了」。
public enum ImageLoadingError: Error, Equatable {
    case cancelled //请求被取消
    case badURL //地址非法或相应不是http
    case http(Int) //返回了非2xx的状态码
    case decodeFailed //数据解不成图片
    case transport(String) //网络传输层错误

    /// 4xx 不重试；网络抖动和 5xx 值得再来一次。
    /// 函数代表是否要重试
    public var isRetryable: Bool {
        switch self {
        case .transport: return true
        case let .http(code): return code >= 500
        case .cancelled, .badURL, .decodeFailed: return false
        }
    }
}
