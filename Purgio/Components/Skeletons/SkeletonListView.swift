//
//  SkeletonListView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 4.02.2026.
//

import UIKit

final class SkeletonListView: UIView {

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var skeletonRows: [SkeletonListRowView] = []
    private let rowCount: Int

    init(rowCount: Int = 4) {
        self.rowCount = rowCount
        super.init(frame: .zero)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(stackView)

        for _ in 0 ..< rowCount {
            let row = SkeletonListRowView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.heightAnchor.constraint(equalToConstant: 220).isActive = true
            skeletonRows.append(row)
            stackView.addArrangedSubview(row)
        }
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func startAnimating() {
        skeletonRows.forEach { $0.startAnimating() }
    }

    func stopAnimating() {
        skeletonRows.forEach { $0.stopAnimating() }
    }

    func fadeOut(completion: (() -> Void)? = nil) {
        UIView.animate(
            withDuration: 0.3,
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
    #Preview("Skeleton List") {
        let list = SkeletonListView(rowCount: 3)
        list.translatesAutoresizingMaskIntoConstraints = false
        list.widthAnchor.constraint(equalToConstant: 360).isActive = true
        return list
    }
#endif
