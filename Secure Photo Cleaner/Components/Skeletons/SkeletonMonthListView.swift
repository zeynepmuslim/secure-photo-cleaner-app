//
//  SkeletonMonthListView.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 4.02.2026.
//

import UIKit

final class SkeletonMonthListView: UIView {

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var skeletonRows: [SkeletonMonthRowView] = []
    private let rowCount: Int

    init(rowCount: Int = 8) {
        self.rowCount = rowCount
        super.init(frame: .zero)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .mainBackground
        addSubview(stackView)

        for _ in 0 ..< rowCount {
            let row = SkeletonMonthRowView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.heightAnchor.constraint(equalToConstant: 68).isActive = true
            skeletonRows.append(row)
            stackView.addArrangedSubview(row)
        }
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
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
    #Preview("Skeleton Month List") {
        let list = SkeletonMonthListView(rowCount: 6)
        list.translatesAutoresizingMaskIntoConstraints = false
        list.widthAnchor.constraint(equalToConstant: 360).isActive = true
        return list
    }
#endif
