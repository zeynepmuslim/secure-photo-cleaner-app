//
//  SimilarSetCell.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.11.2026.
//

import UIKit

/// A similar set in the list: a `SimilarSetCardView` that sizes itself to its content.
final class SimilarSetCell: UICollectionViewCell {
    static let reuseIdentifier = "SimilarSetCell"

    let cardView: SimilarSetCardView = {
        let view = SimilarSetCardView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        contentView.addSubview(cardView)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    // MARK: - Reuse and Sizing

    override func prepareForReuse() {
        super.prepareForReuse()
        cardView.exitStoreModeIfNeeded()
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        // The photos' size follows the card's width, and the card's height follows the photos
        cardView.prepareLayout(forWidth: layoutAttributes.size.width)
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let size = contentView.systemLayoutSizeFitting(
            CGSize(width: layoutAttributes.size.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel)
        attributes.size = CGSize(width: layoutAttributes.size.width, height: ceil(size.height))
        return attributes
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    private struct SimilarSetCellPreview: UIViewRepresentable {
        func makeUIView(context: Context) -> SimilarSetCell {
            SimilarSetCell(frame: CGRect(x: 0, y: 0, width: 353, height: 220))
        }

        func updateUIView(_ uiView: SimilarSetCell, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview {
        SimilarSetCellPreview()
            .frame(height: 220)
            .padding()
            .background(Color(.systemGroupedBackground))
    }
#endif
