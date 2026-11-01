//
//  Untitled.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/30.
//
import UIKit

/// 瀑布流布局：两列，每张图按宽高比算高度，塞进当前最矮的一列。
///UICollectionView是scrollview子类，具有滚动的能力
final class WaterfallLayout: UICollectionViewLayout {//算每个格子放在哪、多大
    var columns = 2 //屏幕设定2列
    var spacing: CGFloat = 8 //格子之间的间距
    var horizontalInset: CGFloat = 8   // 左右边距
    var topInset: CGFloat = 8          // 顶部边距

    /// 由外部提供第 indexPath 个格子的宽高比。布局是几何问题，不认识 Photo。
    var aspectProvider: (IndexPath) -> CGFloat = { _ in 1 } //1代表没人设置它的时候，所有格子按正方形算

    //记录每个格子的位置
//    cache[0] 大概长这样
//    indexPath = [0, 0]                          // 第 0 组第 0 项
    //项目中的photo只有一组
    //第n项就是photo的数组下标
//    frame     = CGRect(x: 8, y: 8, width: 180, height: 120)
    private var cache: [UICollectionViewLayoutAttributes] = []
    //内容总高度
    private var contentHeight: CGFloat = 0

    /// 按容器宽度算出单列宽度
    func columnWidth(for collectionView: UICollectionView) -> CGFloat {
        let total = collectionView.bounds.width - horizontalInset * 2
        return max(1, (total - spacing * CGFloat(columns - 1)) / CGFloat(columns))
    }

    // 一旦标记要重新布局就会调用
    //算所有格子的 frame 并缓存，填进 cache，顺便记下总高度
    override func prepare() {
        super.prepare()
        guard let collectionView else { return }

        //把之前算出的格子清零
        //不清的话，第二次 prepare() 会往旧数据后面追加，同一个格子出现两条记录 → 格子重叠
        cache.removeAll()
        contentHeight = 0
        
        //内容区四周的留白
        let insets = collectionView.adjustedContentInset
        //单列宽度 = (总宽 − 间距) / 列数
        let width = columnWidth(for: collectionView)
        let top = topInset + insets.top
        //每一列已经排到哪了
        //两个格子表示两列当前的高度，每放一张图就更新对应那一列
        //heights[0]左列总高度，[1]右侧总高度
        var heights = Array(repeating: CGFloat.zero, count: columns)

        //是问数据源「一共有几项」。注意它问的是 section 0，我们只有一个 section
        for item in 0..<collectionView.numberOfItems(inSection: 0) {
            //算当前要布局的photo索引，photo多高，用宽/宽高比
            let indexPath = IndexPath(item: item, section: 0)
            let aspect = max(aspectProvider(indexPath), 0.2) //宽高比
            let height = width / aspect

            //选最矮的那一列
            let column = heights.indices.min(by: { heights[$0] < heights[$1] }) ?? 0
            
            //算当前未插入新图片时左上角坐标
            let x = horizontalInset + CGFloat(column) * (width + spacing)
            let y = top + heights[column]

            //造一条记录存进cache，是告诉它「这条属于哪个格子」。之后 UICollectionView 就按这个 frame 摆 cell
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = CGRect(x: x, y: y, width: width, height: height)
            cache.append(attributes)

            //更新两列的高度
            heights[column] = heights[column] + height + spacing
            contentHeight = max(contentHeight, heights[column] + top)
        }
    }

    //都是只读查询
    //需要知道「总共多大、能滚多远」时调用
    //返回内容区的宽高，返回0则滚不动
    //它不做计算，只是把 prepare() 算好的 contentHeight 交出去
    override var collectionViewContentSize: CGSize {
        CGSize(width: collectionView?.bounds.width ?? 0, height: contentHeight)
    }
    //每次滚动、每次重排调用
    //返回当前可见区域的矩形，落在这个矩形里的所有格子
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        cache.filter { $0.frame.intersects(rect) }
    }
    //返回某一photo的 attributes，用于定位
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        cache.first { $0.indexPath == indexPath }
    }
}
