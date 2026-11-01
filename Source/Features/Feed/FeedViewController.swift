//
//  FeedViewController.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/30.
//

import UIKit

final class FeedViewController: UIViewController {
    // 假数据：故意造三种高度，才看得出瀑布流是不是真的在错落
//    private var photos: [Photo] = (0..<12).map { index in
//        Photo(id: "\(index)", author: "mock", width: 600, height: [600, 800, 900][index % 3])
//    }
    
    private let pipeline: ImagePipeline
        private let metrics: PipelineMetrics
        private let viewModel: FeedViewModel
        private let zoomTransition = ZoomTransition()

        private var hud: HUDView?
        private let banner = ErrorBannerView()
        private let emptyState = EmptyStateView()
        private let refreshControl = UIRefreshControl()

        private var lastItemCount = 0
        private var prefetchTasks: [IndexPath: Task<Void, Never>] = [:]
    

    //当执行viewdidload才会访问layout
    private lazy var layout: WaterfallLayout = {
        let layout = WaterfallLayout()
        //prepare时会每次调用这个闭包开始算要布局的photo索引
        layout.aspectProvider = { [weak self] indexPath in
            self?.viewModel.aspectRatio(at: indexPath.item) ?? 1
        }
        return layout
    }()

   
    private lazy var collectionView: UICollectionView = {
        //根据布局创建要显示在整个屏幕的view
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .black
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)//留白
        //把 PhotoCell 这个类和 "PhotoCell" 这个字符串登记给 collectionview
//        登记之后，dequeueReusableCell(withReuseIdentifier:for:) 才知道：
//        从哪个类去创建新 cell
//        用哪个标识去复用池里找
        view.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseID)
        view.dataSource = self//告诉它「有几个格子、每个格子显示什么」由 FeedViewController 回答
        view.delegate = self
        view.prefetchDataSource = self
                view.backgroundView = emptyState
                view.refreshControl = refreshControl
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    init(pipeline: ImagePipeline, metrics: PipelineMetrics, viewModel: FeedViewModel) {
            self.pipeline = pipeline
            self.metrics = metrics
            self.viewModel = viewModel
            super.init(nibName: nil, bundle: nil)
        }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Loupe"
        view.backgroundColor = .black
        navigationController?.navigationBar.tintColor = .white

               refreshControl.tintColor = .white
               refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        banner.onRetry = { [weak self] in
                    Task { await self?.viewModel.retry() }
                }
                banner.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(banner)
                NSLayoutConstraint.activate([
                    banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
                    banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
                    banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
                ])

                let hud = HUDView(pipeline: pipeline, metrics: metrics)
                hud.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(hud)
                NSLayoutConstraint.activate([
                    hud.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
                    hud.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
                ])
                self.hud = hud

                viewModel.onChange = { [weak self] in
                    self?.syncView()
                }
                Task { await viewModel.loadFirstPage() }
    }
    private func syncView() {
            syncItems()
            updateEmptyState()
            updateBanner()
            refreshControl.endRefreshing()
        }
    /// 新增数据用 insertItems，不要 reloadData ——
        /// reloadData 会把所有可见 cell 重建，滚动位置会跳、预取也白做。
        private func syncItems() {
            let newCount = viewModel.photos.count
            guard newCount != lastItemCount else { return }

            if newCount > lastItemCount {
                let paths = (lastItemCount..<newCount).map { IndexPath(item: $0, section: 0) }
                lastItemCount = newCount
                collectionView.performBatchUpdates {
                    self.collectionView.insertItems(at: paths)
                }
            } else {
                // 刷新（数量变少）：回到顶部，否则用户会停在半空
                lastItemCount = newCount
                // index path 全变了，旧预取必须取消，否则会继续下已经滑走的图
                prefetchTasks.values.forEach { $0.cancel() }
                prefetchTasks.removeAll()
                collectionView.reloadData()
                collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top),
                                                animated: false)
            }
        }

        private func updateEmptyState() {
            let isEmpty = viewModel.photos.isEmpty
            emptyState.isHidden = !isEmpty
            guard isEmpty else { return }

            switch viewModel.state {
            case .idle:
                emptyState.update(isLoading: false, message: "下拉刷新")
            case .loading:
                emptyState.update(isLoading: true, message: "加载中…")
            case .loaded:
                emptyState.update(isLoading: false, message: "这里还没有图片")
            case .failed:
                emptyState.update(isLoading: false, message: "没有加载出内容")
            }
        }

        private func updateBanner() {
            if case let .failed(message) = viewModel.state {
                banner.show(message: message)
            } else {
                banner.hide()
            }
        }

        @objc private func handleRefresh() {
            Task { await viewModel.refresh() }
        }
    }
//    private func loadFirstPage() async {
//           // 闭环 1 先直接请求一次：能看到图就算成功。
//           // 闭环 7 会把它抽成 FeedLoading + PhotoRepository + ViewModel，那时才有分页和状态机。
//           guard let url = URL(string: "https://picsum.photos/v2/list?page=1&limit=30") else { return }
//           do {
//               let (data, _) = try await URLSession.shared.data(from: url) //框架的api
//               //用这个 URL 造一个 GET 请求
//               //发出去
//               //等响应，把 body 全部收下来
//               
//               //把 JSON 文本变成 Swift 对象 把 Data 当 JSON 解析
//               photos = try JSONDecoder().decode([Photo].self, from: data) //得到【photo】获取到图片信息
//               collectionView.reloadData() //让列表重新问数据
////               内部做三件事：
////                  ├─ 把数据缓存标记为「失效」
////                  ├─ layout.invalidateLayout()        ← 布局也标记失效
////                  └─ setNeedsLayout()                 ← 请求下一轮重新布局
//               //经过一系列回调跳到prepare()
//           } catch {
//               print("load failed: \(error)")   // 闭环 7 换成错误条
//           }
//       }


// MARK: - 数据源

extension FeedViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.photos.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PhotoCell.reuseID, for: indexPath
        ) as! PhotoCell

        guard let photo = viewModel.photos[safe: indexPath.item] else { return cell }
        let width = layout.columnWidth(for: collectionView)
        cell.configure(with: PhotoEndpoint.request(for: photo, width: width),
                       photo: photo,
                       pipeline: pipeline)
        return cell
    }
}

// MARK: - 代理

extension FeedViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        Task { await viewModel.loadMoreIfNeeded(at: indexPath.item) }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        presentViewer(at: indexPath.item)
    }
}

extension FeedViewController {
    func presentViewer(at index: Int) {
        // 连点两下会在转场中再 present 一次，系统只会打一行 warning 并且状态错乱
        guard presentedViewController == nil else { return }
        guard let window = view.window,
              viewModel.photos.indices.contains(index) else { return }

        let indexPath = IndexPath(item: index, section: 0)
        let frame = layout.layoutAttributesForItem(at: indexPath)?.frame ?? .zero
        let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell

        zoomTransition.sourceFrame = collectionView.convert(frame, to: window)
        zoomTransition.sourceImage = cell?.currentImage

        let viewer = ViewerViewController(photos: viewModel.photos,
                                          startIndex: index,
                                          pipeline: pipeline)

        // 关闭时用「当前翻到的那一页」的图做回缩动画，
        // 否则翻到第 5 张再关闭，会缩成第 1 张（视觉错乱）
        zoomTransition.sourceProvider = { [weak viewer] in
            viewer?.currentSource()
        }

        viewer.transitioningDelegate = self
        present(viewer, animated: true)
    }
}

// MARK: - 预取

extension FeedViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let width = layout.columnWidth(for: collectionView)
        for indexPath in indexPaths {
            guard prefetchTasks[indexPath] == nil,
                  let photo = viewModel.photos[safe: indexPath.item] else { continue }

            let request = PhotoEndpoint.request(for: photo, width: width)
            prefetchTasks[indexPath] = Task.detached(priority: .utility) { [weak self, pipeline] in
                _ = try? await pipeline.image(for: request)
                // 完成后从表里摘掉，否则每个划过的格子都会留一个已完成的 Task
                await MainActor.run { self?.prefetchTasks[indexPath] = nil }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            prefetchTasks[indexPath]?.cancel()
            prefetchTasks[indexPath] = nil
        }
    }
}

// MARK: - 转场

extension FeedViewController: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        zoomTransition.isPresenting = true
        return zoomTransition
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        zoomTransition.isPresenting = false
        return zoomTransition
    }
}

