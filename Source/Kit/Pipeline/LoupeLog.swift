//
//  LoupeLog.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import Foundation
import os

/// 统一日志出口。不用 print：`os.Logger` 能分级、能被 Console.app 过滤、
public enum LoupeLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.example.Loupe"

    public static let pipeline = Logger(subsystem: subsystem, category: "pipeline")
    public static let cache = Logger(subsystem: subsystem, category: "cache")
}
