//
//  CloseButton.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 16.02.2026.
//

import UIKit
import SwiftUI

final class CloseButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupStyle() {
        translatesAutoresizingMaskIntoConstraints = false
        setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)), for: .normal)
        tintColor = .textPrimary
        backgroundColor = .textSecondaryReverse
        layer.cornerRadius = 22

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 44),
            heightAnchor.constraint(equalToConstant: 44)
        ])
    }
}

@available(iOS 17.0, *)
#Preview {
    struct CloseButtonPreview: UIViewRepresentable {
        func makeUIView(context: Context) -> CloseButton {
            CloseButton()
        }
        func updateUIView(_ uiView: CloseButton, context: Context) {}
    }

    return CloseButtonPreview()
        .fixedSize()
        .padding()}
