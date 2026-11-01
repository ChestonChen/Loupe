//
//  ViewerViewController.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import UIKit

final class ViewerViewController: UIViewController {
    private let photos: [Photo]
    private let pipeline: ImagePipeline
    private var index: Int
    private var didSetInitialOffset = false
    private var isCurrentPageZoomed = false
    private var isChromeHidden = false

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0

        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.isPagingEnabled = true
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .never
        view.register(ZoomingCell.self, forCellWithReuseIdentifier: ZoomingCell.reuseID)
        view.dataSource = self
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let closeButton = UIButton(type: .system)
    private let counterLabel = UILabel()
    private let captionContainer = UIView()
    private let captionGradient = CAGradientLayer()
    private let captionLabel = UILabel()

    init(photos: [Photo], startIndex: Int, pipeline: ImagePipeline) {
        self.photos = photos
        self.pipeline = pipeline
        self.index = startIndex
        super.init(nibName: nil, bundle: nil)
        // overFullScreen：下拉时背后能看到列表，而不是一片黑
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var prefersStatusBarHidden: Bool { isChromeHidden }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        setupOverlay()
        setupCaption()
        setupGestures()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        captionGradient.frame = captionContainer.bounds

        guard !didSetInitialOffset, collectionView.bounds.width > 0 else { return }
        didSetInitialOffset = true
        collectionView.collectionViewLayout.invalidateLayout()
        scroll(to: index, animated: false)
        prefetchNeighbors()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        } completion: { _ in
            // 旋转后宽度变了，缩放比例和偏移都失效，必须复位
            (self.collectionView.cellForItem(at: IndexPath(item: self.index, section: 0)) as? ZoomingCell)?
                .resetZoom()
            self.resetZoomState()
            self.scroll(to: self.index, animated: false)
        }
    }

    // MARK: - 对外

    /// 程序化跳页（参考 JXPhotoBrowser 的 scrollToPage）
    func show(index newIndex: Int, animated: Bool = true) {
        guard photos.indices.contains(newIndex) else { return }
        index = newIndex
        updateCaption()
        scroll(to: newIndex, animated: animated)
        prefetchNeighbors()
    }

    /// 转场用：当前这一页的图和它在 window 里的位置
    func currentSource() -> (frame: CGRect, image: UIImage?) {
        guard let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? ZoomingCell else {
            return (.zero, nil)
        }
        return (cell.convert(cell.bounds, to: nil), cell.currentImage)
    }

    // MARK: - 覆盖层

    private func setupOverlay() {
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        closeButton.layer.cornerRadius = 17
        closeButton.accessibilityLabel = "关闭"
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        counterLabel.textColor = .white
        counterLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        counterLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(counterLabel)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 34),
            closeButton.heightAnchor.constraint(equalToConstant: 34),

            counterLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            counterLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
        updateCaption()
    }

    /// 底部渐变 + 作者名（SKPhotoBrowser / AXPhotoViewer 都有 caption）
    private func setupCaption() {
        captionContainer.isUserInteractionEnabled = false
        captionContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(captionContainer)

        captionGradient.colors = [UIColor.clear.cgColor,
                                  UIColor.black.withAlphaComponent(0.75).cgColor]
        captionGradient.locations = [0, 1]
        captionContainer.layer.addSublayer(captionGradient)

        captionLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        captionLabel.font = .systemFont(ofSize: 13)
        captionLabel.textAlignment = .center
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        captionContainer.addSubview(captionLabel)

        NSLayoutConstraint.activate([
            captionContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            captionContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            captionContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            captionContainer.heightAnchor.constraint(equalToConstant: 120),

            captionLabel.leadingAnchor.constraint(equalTo: captionContainer.leadingAnchor, constant: 24),
            captionLabel.trailingAnchor.constraint(equalTo: captionContainer.trailingAnchor, constant: -24),
            captionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    private func updateCaption() {
        counterLabel.text = "\(index + 1) / \(photos.count)"
        captionLabel.text = photos[safe: index]?.author
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    private func setChromeHidden(_ hidden: Bool) {
        isChromeHidden = hidden
        UIView.animate(withDuration: 0.2) {
            let alpha: CGFloat = hidden ? 0 : 1
            self.closeButton.alpha = alpha
            self.counterLabel.alpha = alpha
            self.captionContainer.alpha = alpha
        }
        setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: - 手势

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)

    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: view)

        switch pan.state {
        case .changed:
            let dy = max(0, translation.y)
            let scale = max(0.6, 1 - dy / 1200)
            view.transform = CGAffineTransform(translationX: 0, y: dy).scaledBy(x: scale, y: scale)
            view.alpha = max(0.3, 1 - dy / 600)

        case .ended, .cancelled, .failed:
            let shouldClose = translation.y > 120 || pan.velocity(in: view).y > 600
            if shouldClose {
                view.transform = .identity
                view.alpha = 1
                dismiss(animated: true)
            } else {
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                    self.view.transform = .identity
                    self.view.alpha = 1
                }
            }

        default:
            break
        }
    }

    // MARK: - 分页

    private func scroll(to target: Int, animated: Bool) {
        let width = collectionView.bounds.width
        guard width > 0 else { return }
        collectionView.setContentOffset(CGPoint(x: CGFloat(target) * width, y: 0), animated: animated)
    }

    private func resetZoomState() {
        isCurrentPageZoomed = false
        collectionView.isScrollEnabled = true
    }

    private func prefetchNeighbors() {
        for offset in [-1, 1] {
            let neighbor = index + offset
            guard photos.indices.contains(neighbor) else { continue }
            let request = PhotoEndpoint.request(for: photos[neighbor], width: view.bounds.width)
            Task.detached(priority: .utility) { [pipeline] in
                _ = try? await pipeline.image(for: request)
            }
        }
    }

    private func updateIndex(from scrollView: UIScrollView) {
        guard scrollView.bounds.width > 0 else { return }
        let newIndex = Int((scrollView.contentOffset.x / scrollView.bounds.width).rounded())
        guard photos.indices.contains(newIndex), newIndex != index else { return }
        index = newIndex
        // 翻页后上一页的缩放状态要清掉，否则下拉关闭的手势会被误判成「正在缩放」
        resetZoomState()
        updateCaption()
        prefetchNeighbors()
    }
}

// MARK: - 手势代理

extension ViewerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        guard !isCurrentPageZoomed else { return false }
        let velocity = pan.velocity(in: view)
        return abs(velocity.y) > abs(velocity.x)
    }
}

// MARK: - 数据源

extension ViewerViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        photos.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ZoomingCell.reuseID, for: indexPath
        ) as! ZoomingCell

        guard let photo = photos[safe: indexPath.item] else { return cell }
        let request = PhotoEndpoint.request(for: photo, width: view.bounds.width)
        cell.configure(with: request, pipeline: pipeline)
        cell.onZoomChanged = { [weak self, weak collectionView] zoomed in
            self?.isCurrentPageZoomed = zoomed
            collectionView?.isScrollEnabled = !zoomed
        }
        cell.onSingleTap = { [weak self] in
            guard let self else { return }
            self.setChromeHidden(!self.isChromeHidden)
        }
        return cell
    }
}

// MARK: - 代理

extension ViewerViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        collectionView.bounds.size
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateIndex(from: scrollView)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updateIndex(from: scrollView)
    }
}
