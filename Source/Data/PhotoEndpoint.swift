//
//  PhotoEndpoint.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/30.
//

import Foundation

/// 传输细节集中在这里。换数据源（Unsplash / 自建图床）只改这个文件，模型不动。
enum PhotoEndpoint {
    //把「这张图 + 我要多宽」翻译成一个网址
    /// 点 → 像素的换算只在这里做一次：UI 说「我要 180pt 宽的格子」，
        /// 服务端收到「540×360」，管线收到「长边 540px」。
        static func request(for photo: Photo, width: CGFloat, scale: CGFloat = 3) -> ImageRequest {
            //把屏幕点翻译成像素axb
            let pixelWidth = max(1, Int((width * scale).rounded()))
            let pixelHeight = max(1, Int((CGFloat(pixelWidth) / photo.aspectRatio).rounded()))
            //把你要的放图片id（服务器提供），格子宽高转移成url 打包成请求
            let url = URL(string: "https://picsum.photos/id/\(photo.id)/\(pixelWidth)/\(pixelHeight)")!
            // 解码器限制的是「最长边」：横图取宽，竖图取高，取错会把图解小、放大后变糊
            return ImageRequest(url: url, targetPixel: max(pixelWidth, pixelHeight))
        }
}
