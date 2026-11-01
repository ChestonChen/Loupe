//
//  ImageSource.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/30.
//

import Foundation

/// 这张图是从哪一层拿到的。UI 靠它向用户解释「为什么这么快 / 为什么这么慢」。
public enum ImageSource: Sendable, Equatable {
    case memory
    case disk
    case network
}
