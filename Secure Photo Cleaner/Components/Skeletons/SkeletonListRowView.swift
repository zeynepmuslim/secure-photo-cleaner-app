//
//  SkeletonListRowView.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 4.02.2026.
//

import UIKit

final class SkeletonListRowView: UIView {

    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let thumbnailStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let buttonView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let shimmerLayer = ShimmerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shimmerLayer.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && !shimmerLayer.isAnimating {
            startAnimating()
        }
    }

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        clipsToBounds = true

        for _ in 0 ..< 4 {
            let thumb = UIView()
            thumb.backgroundColor = UIColor.systemGray5
            thumb.layer.cornerRadius = 8
            thumbnailStack.addArrangedSubview(thumb)
        }

        addSubview(headerView)
        addSubview(thumbnailStack)
        addSubview(buttonView)
        layer.addSublayer(shimmerLayer)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            headerView.widthAnchor.constraint(equalToConstant: 120),
            headerView.heightAnchor.constraint(equalToConstant: 16),

            thumbnailStack.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            thumbnailStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            thumbnailStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            thumbnailStack.heightAnchor.constraint(equalToConstant: 120),

            buttonView.topAnchor.constraint(equalTo: thumbnailStack.bottomAnchor, constant: 12),
            buttonView.centerXAnchor.constraint(equalTo: centerXAnchor),
            buttonView.widthAnchor.constraint(equalToConstant: 140),
            buttonView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    func startAnimating() {
        shimmerLayer.startAnimating()
    }

    func stopAnimating() {
        shimmerLayer.stopAnimating()
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview("Skeleton List Row") {
        let row = SkeletonListRowView()
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.widthAnchor.constraint(equalToConstant: 360),
            row.heightAnchor.constraint(equalToConstant: 220)
        ])
        return row
    }
#endif
