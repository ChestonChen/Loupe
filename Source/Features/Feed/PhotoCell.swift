//
//  PhotoCell.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/30.
//

import UIKit

//一个PhotoCell就是列表里的一个格子
final class PhotoCell: UICollectionViewCell {
    static let reuseID = "PhotoCell"//复用标识

    private let imageView = UIImageView()//创建一个图片类，一个格子的视图
    private let failureIcon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
    private var task: Task<Void, Never>? //当前的加载任务 Task<成功类型, 失败类型> 是一个正在跑的异步任务的引用
//    Void    它不返回任何值（结果直接塞进 imageView 了）
//    Never    它不会抛错（错误在这个 Task 内部 catch 掉了）
//    ?    现在可能没有任务在跑
    var currentImage: UIImage? { imageView.image } //当前显示的图

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true //超出边界的子视图裁掉，防止图片出格
        contentView.layer.cornerRadius = 10 //来个圆角
        contentView.backgroundColor = UIColor(white: 0.14, alpha: 1) //没有照片时候的占位颜色

        imageView.contentMode = .scaleAspectFill //图片等比放大到填满格子，超出部分裁掉
        imageView.clipsToBounds = true //图片自己也要裁
        imageView.translatesAutoresizingMaskIntoConstraints = false //约束
        contentView.addSubview(imageView)
        
        failureIcon.tintColor = UIColor.white.withAlphaComponent(0.35)
                failureIcon.isHidden = true
                failureIcon.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(failureIcon)
        //图片先被 imageView 裁成矩形，整体再被 contentView 裁成圆角
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            // 失败图标居中：只 addSubview 不给约束，它会被摆在 0,0 且尺寸为 0 —— 永远看不见
            failureIcon.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            failureIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    //发起加载，完成后设图并淡入
    func configure(with request: ImageRequest, photo: Photo, pipeline: ImagePipeline) {
            task?.cancel() //先停掉上一个还没下完的
            imageView.image = nil //清空，别让旧图残留

            isAccessibilityElement = true
            accessibilityTraits = .image
            accessibilityLabel = "图片，作者 \(photo.author)"

            task = Task { [weak self] in
                do {
                    let response = try await pipeline.image(for: request)
                    guard !Task.isCancelled else { return } //途中被取消了就不必再设图
                    await MainActor.run { //回主线程改 UI
                        guard let self else { return }
                        self.imageView.image = response.image
                        self.failureIcon.isHidden = true
                        UIView.transition(with: self.imageView, //淡入 而不是"啪"地出现
                                          duration: 0.22,
                                          options: .transitionCrossDissolve) {}
                    }
                } catch {
                    // 闭环 7 会补「失败图标」
                    guard !Task.isCancelled, !isCancellation(error) else { return }
                    await MainActor.run { self?.failureIcon.isHidden = false }
                }
            }
        }
      //复用前取消任务、清图 格子被回收时调用
    //UICollectionViewCell 的固定回调，回收前必调
        override func prepareForReuse() {
            super.prepareForReuse()
            task?.cancel()
            task = nil
            imageView.image = nil
            failureIcon.isHidden = true
        }
        private func isCancellation(_ error: Error) -> Bool {
            if let loadingError = error as? ImageLoadingError, case .cancelled = loadingError { return true }
            return error is CancellationError
        }
}
