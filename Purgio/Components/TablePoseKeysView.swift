//
//  TablePoseKeysView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 10.11.2026.
//

import UIKit

/// A rounded white tray with a full-width Store key on top and two equal keys below it, Delete
/// (leading) and Keep (trailing). Same segment look as ActionGripView. MonthReview shows it on the
/// base in the iPhone Duo table layout; the keys run the same code as an up, left or right swipe.
final class TablePoseKeysView: UIView {

    var onStore: (() -> Void)?
    var onDelete: (() -> Void)?
    var onKeep: (() -> Void)?

    private enum Layout {
        static let segmentCornerRadius: CGFloat =
            GeneralConstants.ActionGrip.trayCornerRadius - GeneralConstants.ActionGrip.inset
        static let minimumKeyHeight: CGFloat = GeneralConstants.ButtonSize.medium
    }

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = GeneralConstants.ActionGrip.inset
        stack.distribution = .fill
        return stack
    }()

    private let primaryRow: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = GeneralConstants.ActionGrip.inset
        stack.distribution = .fillEqually
        return stack
    }()

    private let storeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let deleteButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let keepButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.ActionGrip.trayCornerRadius
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = GeneralConstants.ActionGrip.Shadow.opacity
        layer.shadowOffset = CGSize(width: 0, height: GeneralConstants.ActionGrip.Shadow.offsetY)
        layer.shadowRadius = GeneralConstants.ActionGrip.Shadow.radius

        storeButton.addTarget(self, action: #selector(handleStoreTap), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(handleDeleteTap), for: .touchUpInside)
        keepButton.addTarget(self, action: #selector(handleKeepTap), for: .touchUpInside)

        addSubview(stackView)
        stackView.addArrangedSubview(storeButton)
        stackView.addArrangedSubview(primaryRow)
        primaryRow.addArrangedSubview(deleteButton)
        primaryRow.addArrangedSubview(keepButton)
    }

    private func setupConstraint() {
        let inset = GeneralConstants.ActionGrip.inset
        // Store and the Delete | Keep row share the tray evenly; Store stops growing at its segment
        // height, so a tall tray gives the extra room to Delete and Keep
        let equalRows = storeButton.heightAnchor.constraint(equalTo: primaryRow.heightAnchor)
        equalRows.priority = .defaultHigh

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),

            equalRows,
            storeButton.heightAnchor.constraint(
                lessThanOrEqualToConstant: GeneralConstants.ActionGrip.storeSegmentHeight),
            storeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.minimumKeyHeight),
            primaryRow.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.minimumKeyHeight)
        ])
    }

    // MARK: - Configuration

    func configure(storeTitle: String, deleteTitle: String, keepTitle: String) {
        storeButton.configuration = .actionSegment(
            title: storeTitle, systemImage: "archivebox", iconSize: 22,
            iconColor: ThemeManager.Colors.statusYellow, cornerRadius: Layout.segmentCornerRadius)
        deleteButton.configuration = .actionSegment(
            title: deleteTitle, systemImage: "trash", iconSize: 28,
            iconColor: ThemeManager.Colors.statusRed, cornerRadius: Layout.segmentCornerRadius)
        keepButton.configuration = .actionSegment(
            title: keepTitle, systemImage: "checkmark", iconSize: 28,
            iconColor: ThemeManager.Colors.statusGreen, cornerRadius: Layout.segmentCornerRadius)

        storeButton.accessibilityLabel = storeTitle
        deleteButton.accessibilityLabel = deleteTitle
        keepButton.accessibilityLabel = keepTitle
    }

    // MARK: - Actions

    @objc private func handleStoreTap() {
        onStore?()
    }

    @objc private func handleDeleteTap() {
        onDelete?()
    }

    @objc private func handleKeepTap() {
        onKeep?()
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct TablePoseKeysPreview: UIViewRepresentable {
        func makeUIView(context: Context) -> TablePoseKeysView {
            let keys = TablePoseKeysView()
            keys.configure(storeTitle: "Store", deleteTitle: "Delete", keepTitle: "Keep")
            return keys
        }

        func updateUIView(_ uiView: TablePoseKeysView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Table pose keys") {
        TablePoseKeysPreview()
            .frame(width: 545, height: 361)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
    }
#endif
