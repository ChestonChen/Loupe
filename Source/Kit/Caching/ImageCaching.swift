//
//  ImageCaching.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import UIKit

/// 内存缓存：存「解码后的图」。
///
/// 为什么和 DataCaching 分开：内存里放的是 UIImage（按像素计费），
/// 磁盘上放的是压缩字节（按文件计费）。塞进同一个协议，必然出现
/// 「这个方法在这里没意义」的实现。
/// 内存缓存的接口
public protocol ImageCaching: Sendable {
    //取缓存
    func image(for key: String) async -> UIImage?
    //存缓存
    func store(_ image: UIImage, for key: String) async
    
    func removeAll() async

    /// 已用字节（给 HUD 拉取快照用，不用事件推送）
    var cost: Int { get async }
    //上限
    var costLimit: Int { get }
}
