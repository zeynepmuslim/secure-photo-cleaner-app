//
//  SkeletonLoadingView.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 4.02.2026.
//

import UIKit

final class SkeletonLoadingView: UIView {

    private let titleView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let progressView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let subtitleView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray5
        view.layer.cornerRadius = 6
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
        if window != nil {
            startAnimating()
        } else {
            stopAnimating()
        }
    }

    private func setupUI() {
        addSubview(titleView)
        addSubview(progressView)
        addSubview(subtitleView)
        layer.addSublayer(shimmerLayer)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            titleView.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -60),
            titleView.widthAnchor.constraint(equalToConstant: 180),
            titleView.heightAnchor.constraint(equalToConstant: 24),

            progressView.topAnchor.constraint(equalTo: titleView.bottomAnchor, constant: 30),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            progressView.heightAnchor.constraint(equalToConstant: 8),

            subtitleView.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 16),
            subtitleView.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleView.widthAnchor.constraint(equalToConstant: 100),
            subtitleView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    func startAnimating() {
        shimmerLayer.startAnimating()
    }

    func stopAnimating() {
        shimmerLayer.stopAnimating()
    }

    func fadeOut(completion: (() -> Void)? = nil) {
        UIView.animate(
            withDuration: 0.2,
            animations: {
                self.alpha = 0
            }
        ) { _ in
            self.stopAnimating()
            self.removeFromSuperview()
            completion?()
        }
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview("Skeleton Loading") {
        let loading = SkeletonLoadingView()
        loading.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loading.widthAnchor.constraint(equalToConstant: 360),
            loading.heightAnchor.constraint(equalToConstant: 300)
        ])
        return loading
    }
#endif
