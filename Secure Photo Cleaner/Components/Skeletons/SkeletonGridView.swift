//
//  SkeletonGridView.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 4.02.2026.
//

import UIKit

final class SkeletonGridView: UIView {

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var skeletonCells: [SkeletonCellView] = []
    private let columns: Int
    private let rows: Int

    init(columns: Int = 3, rows: Int = 4) {
        self.columns = columns
        self.rows = rows
        super.init(frame: .zero)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(stackView)

        for _ in 0 ..< rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 2
            rowStack.distribution = .fillEqually

            for _ in 0 ..< columns {
                let cell = SkeletonCellView()
                skeletonCells.append(cell)
                rowStack.addArrangedSubview(cell)
            }

            stackView.addArrangedSubview(rowStack)
        }
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func startAnimating() {
        skeletonCells.forEach { $0.startShimmerAnimation() }
    }

    func stopAnimating() {
        skeletonCells.forEach { $0.stopShimmerAnimation() }
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
    #Preview("Skeleton Grid") {
        let grid = SkeletonGridView(columns: 3, rows: 4)
        grid.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grid.widthAnchor.constraint(equalToConstant: 300),
            grid.heightAnchor.constraint(equalToConstant: 400)
        ])
        return grid
    }
#endif
