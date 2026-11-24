//
//  StorageLedgerRowView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 23.11.2026.
//

import UIKit

/// One row of the storage sheet's ledger: a capsule mark in the segment's color, the name
/// (with an optional count under it) and the size trailing. One VoiceOver element.
final class StorageLedgerRowView: UIView {

    private let markView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = GeneralConstants.LegendCapsule.rowWidth / 2
        view.layer.cornerCurve = .continuous
        return view
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let sizeLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .bold)
        label.textColor = .label
        label.textAlignment = .natural
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private var topConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        isAccessibilityElement = true
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(countLabel)
        addSubview(markView)
        addSubview(textStack)
        addSubview(sizeLabel)
        setupConstraint()
    }

    private func setupConstraint() {
        let top = textStack.topAnchor.constraint(equalTo: topAnchor, constant: 11)
        let bottom = textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -11)
        topConstraint = top
        bottomConstraint = bottom

        NSLayoutConstraint.activate([
            markView.leadingAnchor.constraint(equalTo: leadingAnchor),
            markView.centerYAnchor.constraint(equalTo: centerYAnchor),
            markView.widthAnchor.constraint(equalToConstant: GeneralConstants.LegendCapsule.rowWidth),
            markView.heightAnchor.constraint(equalToConstant: GeneralConstants.LegendCapsule.rowHeight),
            markView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 8),

            textStack.leadingAnchor.constraint(equalTo: markView.trailingAnchor, constant: 12),
            top,
            bottom,

            sizeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: textStack.trailingAnchor, constant: 12),
            sizeLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            sizeLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    /// A nil `count` hides the count line; with `reservesCountLine` it keeps its height, invisible,
    /// so the row doesn't change size between states.
    func configure(color: UIColor, name: String, count: String?, size: String, reservesCountLine: Bool = false) {
        markView.backgroundColor = color
        nameLabel.text = name
        countLabel.text = count ?? " "
        countLabel.alpha = count == nil ? 0 : 1
        // Set only on a change: a redundant isHidden inside an animation block sticks in a stack view
        let hidesCount = count == nil && !reservesCountLine
        if countLabel.isHidden != hidesCount { countLabel.isHidden = hidesCount }
        sizeLabel.text = size
        accessibilityLabel = [name, count, size].compactMap { $0 }.joined(separator: ", ")
    }

    /// The row's top and bottom padding (11 regular, 8 compact).
    func setVerticalPadding(_ padding: CGFloat) {
        topConstraint?.constant = padding
        bottomConstraint?.constant = -padding
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct StorageLedgerRowPreview: UIViewRepresentable {
        func makeUIView(context: Context) -> StorageLedgerRowView {
            let row = StorageLedgerRowView()
            row.configure(color: .photo100, name: "Photos", count: "4,312 photos", size: "12.4 GB")
            return row
        }

        func updateUIView(_ uiView: StorageLedgerRowView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Ledger row", traits: .sizeThatFitsLayout) {
        StorageLedgerRowPreview().frame(width: 340, height: 60).padding()
    }
#endif
