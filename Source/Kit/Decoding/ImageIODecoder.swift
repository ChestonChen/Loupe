//
//  ImageIODecoder.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/30.
//

import UIKit
//解码器的实现
struct ImageIODecoder: ImageDecoding {
    public init() {}
    func decode(_ data: Data, request: ImageRequest) -> UIImage? {
        //UIImage(data: data)   // 闭环 4 会换成 ImageIO 降采样
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
                guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
                    return nil
                }
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceThumbnailMaxPixelSize: request.targetPixel,
                ]
                guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                    return nil
                }
                return UIImage(cgImage: cgImage)
    }
}
