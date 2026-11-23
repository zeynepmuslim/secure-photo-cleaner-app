//
//  ActionRuleCapsuleView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 22.11.2026.
//

import UIKit

/// The rule capsule of an undo action: the action's color holding its symbol (no circle) in the
/// action's ink (`displayInk`: black on yellow, white on red and green). Shared by the Undo
/// History rows and the history detail sheet.
final class ActionRuleCapsuleView: UIView {

    static let size = CGSize(width: 24, height: 38)

    private let symbolView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize { Self.size }

    private func setupUI() {
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        isAccessibilityElement = false
        addSubview(symbolView)
        NSLayoutConstraint.activate([
            symbolView.centerXAnchor.constraint(equalTo: centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(type: UndoAction.ActionType, color: UIColor) {
        backgroundColor = color
        symbolView.tintColor = type.displayInk
        symbolView.image = UIImage(systemName: Self.symbol(for: type))
    }

    /// The action's own symbol without its outline circle.
    static func symbol(for type: UndoAction.ActionType) -> String {
        switch type {
        case .delete: return "trash"
        case .keep: return "checkmark"
        case .store: return "archivebox"
        }
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    private struct ActionRuleCapsulePreview: UIViewRepresentable {
        func makeUIView(context: Context) -> UIStackView {
            let types: [UndoAction.ActionType] = [.delete, .keep, .store]
            let stack = UIStackView(arrangedSubviews: types.map { type in
                let capsule = ActionRuleCapsuleView()
                capsule.configure(type: type, color: type.displayColor)
                return capsule
            })
            stack.spacing = 12
            return stack
        }

        func updateUIView(_ uiView: UIStackView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Delete, Keep, Store") {
        ActionRuleCapsulePreview()
            .fixedSize()
            .padding()
    }
#endif
