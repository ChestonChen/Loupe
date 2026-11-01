//
//  Photo.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/30.
//
import CoreGraphics
import Foundation

//只说「这是一张什么图」,不认识任何CDN
struct Photo: Identifiable, Hashable, Decodable {
    let id : String //图片 id，用来拼地址、区分列表项
    let author : String //作者名，显示在全屏页底部
    let width : Int //原图宽
    let height : Int //原图高
    var aspectRatio: CGFloat { //计算宽高比
            CGFloat(width) / CGFloat(max(height, 1))
        }
}
//给所有数组扩展一个下标 相当于
//if index >= 0 && index < count {
//    return self[index]
//} else {
//    return nil
//}
//返回一个可能为nil的类型，防止取不到资源直接崩
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
