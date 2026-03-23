//
//  SkeletonMonthRowView.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 4.02.2026.
//

import UIKit

final class SkeletonMonthRowView: UIView {

    private let titlePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let subtitlePlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let chevronPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 3
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let shimmerLayer = ShimmerLayer.transparent()

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
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.borderColorGray.cgColor
        clipsToBounds = true

        addSubview(titlePlaceholder)
        addSubview(subtitlePlaceholder)
        addSubview(chevronPlaceholder)
        layer.addSublayer(shimmerLayer)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            titlePlaceholder.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            titlePlaceholder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titlePlaceholder.widthAnchor.constraint(equalToConstant: 140),
            titlePlaceholder.heightAnchor.constraint(equalToConstant: 16),

            subtitlePlaceholder.topAnchor.constraint(equalTo: titlePlaceholder.bottomAnchor, constant: 8),
            subtitlePlaceholder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subtitlePlaceholder.widthAnchor.constraint(equalToConstant: 100),
            subtitlePlaceholder.heightAnchor.constraint(equalToConstant: 12),

            chevronPlaceholder.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronPlaceholder.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevronPlaceholder.widthAnchor.constraint(equalToConstant: 14),
            chevronPlaceholder.heightAnchor.constraint(equalToConstant: 14)
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
    #Preview("Skeleton Month Row") {
        let row = SkeletonMonthRowView()
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.widthAnchor.constraint(equalToConstant: 360),
            row.heightAnchor.constraint(equalToConstant: 68)
        ])
        return row
    }
#endif
