//
//  ImageResponse.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/30.
//

import UIKit

/// 管线的返回值：一张图 + 它从哪来。
public struct ImageResponse: @unchecked Sendable {
    public let image: UIImage
    public let source: ImageSource

    public init(image: UIImage, source: ImageSource) {
        self.image = image
        self.source = source
    }
}
