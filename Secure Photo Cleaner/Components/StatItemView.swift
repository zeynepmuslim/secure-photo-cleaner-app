//
//  StatItemView.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import UIKit

final class StatItemView: UIView {
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    private let label: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        label.textColor = .label.withAlphaComponent(0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let stack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    init() {
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        stack.addArrangedSubview(iconImageView)
        stack.addArrangedSubview(label)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),

            iconImageView.widthAnchor.constraint(equalToConstant: 14),
            iconImageView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    func configure(systemName: String, color: UIColor, text: String, iconPointSize: CGFloat = 13) {
        let config = UIImage.SymbolConfiguration(pointSize: iconPointSize, weight: .semibold)
        iconImageView.image = UIImage(systemName: systemName, withConfiguration: config)
        iconImageView.tintColor = color
        label.text = text
    }
}

#if DEBUG
    import SwiftUI

    #Preview("Deleted") {
        StatItemViewWrapper(systemName: "trash.fill", color: .systemRed, text: "12 deleted")
            .frame(width: 120, height: 20)
    }

    #Preview("Kept") {
        StatItemViewWrapper(systemName: "checkmark.circle.fill", color: .systemGreen, text: "45 kept")
            .frame(width: 120, height: 20)
    }

    #Preview("Stored") {
        StatItemViewWrapper(systemName: "archivebox.fill", color: .systemOrange, text: "3 stored")
            .frame(width: 120, height: 20)
    }

    struct StatItemViewWrapper: UIViewRepresentable {
        let systemName: String
        let color: UIColor
        let text: String

        func makeUIView(context: Context) -> StatItemView {
            let view = StatItemView()
            view.configure(systemName: systemName, color: color, text: text)
            return view
        }

        func updateUIView(_ uiView: StatItemView, context: Context) {}
    }
#endif
