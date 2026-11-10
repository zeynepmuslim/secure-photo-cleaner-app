//
//  SettingsGroupView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 10.11.2026.
//

import UIKit

/// A grouped-list card of `SettingsGroupRowView`s (iPhone Duo split layouts). Rows can be
/// hidden; the first visible row never shows a separator.
final class SettingsGroupView: UIView {

    private let rowsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var rows: [SettingsGroupRowView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    func configure(rows: [SettingsGroupRowView]) {
        self.rows.forEach { $0.removeFromSuperview() }
        self.rows = rows
        rows.forEach { rowsStack.addArrangedSubview($0) }
        updateSeparators()
    }

    func setRow(_ row: SettingsGroupRowView, hidden: Bool, animated: Bool) {
        guard row.isHidden != hidden else { return }
        let changes = {
            row.isHidden = hidden
            row.alpha = hidden ? 0 : 1
            self.updateSeparators()
        }
        if animated {
            UIView.animate(withDuration: 0.3) {
                changes()
                self.superview?.layoutIfNeeded()
            }
        } else {
            changes()
        }
    }

    private func updateSeparators() {
        let firstVisible = rows.first { !$0.isHidden }
        rows.forEach { $0.showsSeparator = $0 !== firstVisible }
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.CornerRadius.card
        layer.cornerCurve = .continuous
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(rowsStack)
        NSLayoutConstraint.activate([
            rowsStack.topAnchor.constraint(equalTo: topAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
