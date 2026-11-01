//
//  PipelineEvent.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import Foundation

/// 管线对外发的事件。观测层（HUD）订阅它，管线不认识 HUD。
public enum PipelineEvent: Sendable {
    case memoryHit //内存命中
    case diskHit    //磁盘命中
    case networkLoaded(bytes: Int) //网络下载成功，附带字节数
    case decoded(seconds: TimeInterval) //解码完成，附带耗时
    case failed(ImageLoadingError)  //失败
}
