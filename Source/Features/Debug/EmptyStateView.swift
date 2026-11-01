//
//  EmptyStateView.swift
//  Loupe
//
//  Created by chenzetong on 2026/10/31.
//

import UIKit

/// 首屏加载 / 空结果时占据列表背景。
final class EmptyStateView: UIView {
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false

        label.textColor = UIColor.white.withAlphaComponent(0.6)
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(spinner)
        addSubview(label)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),

            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 12),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(isLoading: Bool, message: String?) {
        label.text = message
        if isLoading {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }
}
