//
//  ZoomTransition.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import UIKit

/// 共享元素转场动画：从被点的格子放大到全屏，关闭时缩回去。
final class ZoomTransition: NSObject, UIViewControllerAnimatedTransitioning {
    var isPresenting = true
    var sourceFrame: CGRect = .zero
    var sourceImage: UIImage?
    /// 关闭时用它拿「当前那一页」的图和位置；拿不到就退回 sourceFrame/sourceImage
    var sourceProvider: (() -> (frame: CGRect, image: UIImage?)?)?

    func transitionDuration(using context: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.35
    }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        let container = context.containerView

        // 开了「减弱动态效果」就不做缩放，改成淡入淡出
        if UIAccessibility.isReduceMotionEnabled {
            crossFade(context: context, container: container)
            return
        }

        let resolved = sourceProvider?()
        let frame = resolved?.frame ?? sourceFrame
        let image = resolved?.image ?? sourceImage

        guard let sourceImage = image else {
            // 缩略图还没加载出来时没有源图可缩放，退回淡入，避免「啪」地出现
            crossFade(context: context, container: container)
            return
        }

        let snapshot = UIImageView(image: sourceImage)
        snapshot.contentMode = .scaleAspectFill
        snapshot.clipsToBounds = true
        snapshot.layer.cornerRadius = 10
        container.addSubview(snapshot)

        let targetFrame = Self.aspectFitFrame(for: sourceImage.size, in: container.bounds)

        if isPresenting {
            guard let toView = context.view(forKey: .to) else {
                context.completeTransition(false)
                return
            }
            toView.frame = container.bounds
            toView.alpha = 0
            container.addSubview(toView)

            snapshot.frame = frame
            UIView.animate(withDuration: 0.35, delay: 0,
                           usingSpringWithDamping: 0.88, initialSpringVelocity: 0,
                           options: .curveEaseInOut) {
                snapshot.frame = targetFrame
                snapshot.layer.cornerRadius = 0
                toView.alpha = 1
            } completion: { _ in
                snapshot.removeFromSuperview()
                context.completeTransition(!context.transitionWasCancelled)
            }
        } else {
            guard let fromView = context.view(forKey: .from) else {
                context.completeTransition(false)
                return
            }
            snapshot.frame = targetFrame
            UIView.animate(withDuration: 0.28, delay: 0,
                           options: .curveEaseInOut) {
                snapshot.frame = frame
                snapshot.layer.cornerRadius = 10
                fromView.alpha = 0
            } completion: { _ in
                snapshot.removeFromSuperview()
                fromView.removeFromSuperview()
                context.completeTransition(!context.transitionWasCancelled)
            }
        }
    }

    private func crossFade(context: UIViewControllerContextTransitioning, container: UIView) {
        let key: UITransitionContextViewKey = isPresenting ? .to : .from
        guard let target = context.view(forKey: key) else {
            context.completeTransition(false)
            return
        }

        if isPresenting {
            target.frame = container.bounds
            target.alpha = 0
            container.addSubview(target)
        }

        UIView.animate(withDuration: 0.2) {
            target.alpha = self.isPresenting ? 1 : 0
        } completion: { _ in
            if !self.isPresenting { target.removeFromSuperview() }
            context.completeTransition(!context.transitionWasCancelled)
        }
    }

    static func aspectFitFrame(for size: CGSize, in bounds: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return bounds }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let width = size.width * scale
        let height = size.height * scale
        return CGRect(x: bounds.midX - width / 2,
                      y: bounds.midY - height / 2,
                      width: width,
                      height: height)
    }
}
