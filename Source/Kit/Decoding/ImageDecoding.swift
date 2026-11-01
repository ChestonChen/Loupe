//
//  ImageDecoding.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/30.
//

import Foundation
import UIKit

/// 解码器协议。为什么抽它：换 WebP/AVIF/自定义格式时，管线一行不用改。
///  遵守协议的对象必须拿到一个数据以后给我一个uiimage
///  把字节变成图片」这件事的接口
public protocol ImageDecoding: Sendable {
    func decode(_ data: Data, request: ImageRequest) -> UIImage?
}
