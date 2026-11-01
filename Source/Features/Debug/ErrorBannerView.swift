//
//  ErrorBannerView.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import UIKit

/// 顶部错误条 + 重试按钮。比 `navigationItem.prompt` 强的地方：
/// 它会自动消失、有重试入口、不影响导航栏布局。
final class ErrorBannerView: UIView {
    var onRetry: (() -> Void)?

    private let label = UILabel()
    private let retryButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.systemRed.withAlphaComponent(0.92)
        layer.cornerRadius = 10

        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false

        retryButton.setTitle("重试", for: .normal)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        retryButton.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
        retryButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(label)
        addSubview(retryButton)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            retryButton.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            retryButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            retryButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(message: String) {
        label.text = message
        isHidden = false
    }

    func hide() {
        isHidden = true
    }

    @objc private func handleRetry() {
        hide()
        onRetry?()
    }
}
