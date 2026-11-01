//
//  ZoomingCell.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import UIKit

/// 全屏里的一页：三态（加载中 / 成功 / 失败）+ UIScrollView 缩放。
/// 失败态必须可重试
/// 网络图不可能保证 100% 成功，没有重试入口的浏览器在弱网下就是死的。
final class ZoomingCell: UICollectionViewCell {
    static let reuseID = "ZoomingCell"

    enum State {/// 全屏里的一页：三态（加载中 / 成功 / 失败）+ UIScrollView 缩放。
        case loading //加载中
        case loaded(UIImage) //加载完成
        case failed //加载失败
    }

    /// 缩放状态变化时通知外层，用来临时关掉分页滚动
    /// 手势冲突时，只做图片局部放大，而不是切到下一张
    var onZoomChanged: ((Bool) -> Void)?
    /// 单击（用来显隐控件）
    /// 用户点击图片时，进入沉浸式，隐藏其他控件
    var onSingleTap: (() -> Void)?

    private let scrollView = UIScrollView()//缩放容器，捏合/双击/平移都由它管
    private let imageView = UIImageView()//显示图片，被 scrollView 缩放
    private let spinner = UIActivityIndicatorView(style: .large) //加载的菊花符号
    private let retryButton = UIButton(type: .system) //加载失败的重试按钮

    private var task: Task<Void, Never>? //加载任务
    private var currentRequest: ImageRequest? //记住请求，reloading时知道要请求哪张图
    private var pipeline: ImagePipeline? //
    private(set) var state: State = .loading //记录状态

    //搭界面
    override init(frame: CGRect) {
        super.init(frame: frame)

        scrollView.delegate = self
        scrollView.minimumZoomScale = 1 //设计最大最小放缩比例
        scrollView.maximumZoomScale = 4
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)

        spinner.color = .white
        spinner.hidesWhenStopped = true //停止转动时自动隐藏
        spinner.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(spinner)

        var config = UIButton.Configuration.plain()
        config.title = "加载失败，点击重试"
        config.image = UIImage(systemName: "arrow.clockwise")
        config.imagePadding = 6
        config.baseForegroundColor = .white
        retryButton.configuration = config
        retryButton.titleLabel?.font = .systemFont(ofSize: 14)
        retryButton.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
        retryButton.isHidden = true
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(retryButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            retryButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            retryButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])

        //双击手势
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        // 单击依赖双击失败，否则双击时也会先触发一次单击
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(singleTap)
    }

    //保证双击时不会先触发一次单击
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var currentImage: UIImage? {
        if case let .loaded(image) = state { return image }
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = contentView.bounds
        //用户正在缩放时不插手
        guard scrollView.zoomScale <= 1.01 else { return }
        imageView.frame = scrollView.bounds
        scrollView.contentSize = scrollView.bounds.size
    }

    /// 翻页 / 旋转时调用：把缩放和偏移都归零，并通知外层恢复分页滚动
    /// 否则上一页的缩放状态会残留到下一页
    func resetZoom() {
        scrollView.setZoomScale(1, animated: false)
        scrollView.contentOffset = .zero
        onZoomChanged?(false)
    }

    func configure(with request: ImageRequest, pipeline: ImagePipeline) {
        currentRequest = request
        self.pipeline = pipeline
        scrollView.setZoomScale(1, animated: false)
        scrollView.contentOffset = .zero
        load()
    }

    //在「从复用池取出前」调用，清旧资源
    override func prepareForReuse() {
        super.prepareForReuse()
        task?.cancel()
        task = nil
        currentRequest = nil
        pipeline = nil
        apply(.loading)
        scrollView.setZoomScale(1, animated: false)
    }

    // 加载图片
    private func load() {
        guard let request = currentRequest, let pipeline else { return }
        task?.cancel()
        apply(.loading)

        task = Task { [weak self] in
            do {
                let response = try await pipeline.image(for: request)
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.apply(.loaded(response.image)) }
            } catch {
                guard !Task.isCancelled else { return }
                if case .cancelled = (error as? ImageLoadingError) { return }
                await MainActor.run { self?.apply(.failed) }
            }
        }
    }
    //改三态的状态
    private func apply(_ newState: State) {
        state = newState
        switch newState {
        case .loading:
            imageView.image = nil
            spinner.startAnimating()
            retryButton.isHidden = true
        case let .loaded(image):
            spinner.stopAnimating()
            retryButton.isHidden = true
            imageView.image = image
        case .failed:
            spinner.stopAnimating()
            retryButton.isHidden = false
        }
    }
    //重新加载
    @objc private func handleRetry() {
        load()
    }
    //隐藏外部控件
    @objc private func handleSingleTap() {
        onSingleTap?()
    }
    //处理双击的动作，放大/还原
    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard case .loaded = state else { return }

        if scrollView.zoomScale > 1.01 {
            scrollView.setZoomScale(1, animated: true)
            return
        }
        let point = recognizer.location(in: imageView)
        let size = CGSize(width: scrollView.bounds.width / 2.5,
                          height: scrollView.bounds.height / 2.5)
        let rect = CGRect(x: point.x - size.width / 2,
                          y: point.y - size.height / 2,
                          width: size.width,
                          height: size.height)
        scrollView.zoom(to: rect, animated: true)
    }
}

extension ZoomingCell: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        onZoomChanged?(scrollView.zoomScale > 1.01)
    }
}
