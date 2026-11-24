//
//  SimilarSummaryView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.11.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let unknownSize = "–"
    static func setsToCheck(_ count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("similarPhotos.summarySets", comment: "Similar photos summary, e.g. '6 sets to check'"),
            count)
    }
    static func done(_ count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("similarPhotos.summaryDone", comment: "Similar photos summary: confirmed sets, e.g. '2 done'"),
            count)
    }
    static func toFree(_ size: String) -> String {
        String(
            format: NSLocalizedString("similarPhotos.summaryFree", comment: "Similar photos summary: size to free, e.g. '~73 MB to free'"),
            size)
    }
}

/// The Similar Photos summary: "6 sets to check · 2 done" leading and "~73 MB to free" trailing.
/// A plain line at the top of the list, and the content of the summary card on the Duo's
/// upright inner display.
final class SimilarSummaryView: UIView {

    private enum Layout {
        static let fontSize: CGFloat = 13
        static let spacing: CGFloat = 8
    }

    private let setsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Layout.fontSize)
        label.textColor = .secondaryLabel
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let freeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Layout.fontSize)
        label.textColor = .secondaryLabel
        label.textAlignment = .natural
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        isAccessibilityElement = true
        addSubview(setsLabel)
        addSubview(freeLabel)

        NSLayoutConstraint.activate([
            setsLabel.topAnchor.constraint(equalTo: topAnchor),
            setsLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            setsLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            setsLabel.trailingAnchor.constraint(lessThanOrEqualTo: freeLabel.leadingAnchor, constant: -Layout.spacing),

            freeLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            freeLabel.firstBaselineAnchor.constraint(equalTo: setsLabel.firstBaselineAnchor)
        ])
    }

    /// `bytesToFree` is the size of the photos marked delete in sets not yet confirmed; nil
    /// while the sizes are still being read.
    func configure(setsToCheck: Int, done: Int, bytesToFree: Int64?) {
        let setsText = Strings.setsToCheck(setsToCheck)
        var text = setsText
        if done > 0 {
            text += " · " + Strings.done(done)
        }
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [.font: UIFont.systemFont(ofSize: Layout.fontSize), .foregroundColor: UIColor.secondaryLabel])
        // The count leads in ink
        let number = String.localizedStringWithFormat("%lld", setsToCheck)
        if let range = setsText.range(of: number) {
            attributed.addAttributes(
                [.font: UIFont.systemFont(ofSize: Layout.fontSize, weight: .bold), .foregroundColor: UIColor.label],
                range: NSRange(range, in: text))
        }
        setsLabel.attributedText = attributed

        if let bytesToFree {
            freeLabel.text = bytesToFree > 0 ? Strings.toFree(bytesToFree.formattedBytes()) : nil
        } else {
            freeLabel.text = Strings.unknownSize
        }

        accessibilityLabel = [text, bytesToFree == nil ? nil : freeLabel.text]
            .compactMap { $0 }.joined(separator: ", ")
    }
}

/// The summary as the list's first item.
final class SimilarSummaryCell: UICollectionViewCell {
    static let reuseIdentifier = "SimilarSummaryCell"

    let summaryView: SimilarSummaryView = {
        let view = SimilarSummaryView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(summaryView)
        // A line of text, 4pt off the cards' edge so it reads with their corners
        NSLayoutConstraint.activate([
            summaryView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            summaryView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            summaryView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            summaryView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    private struct SimilarSummaryPreview: UIViewRepresentable {
        func makeUIView(context: Context) -> SimilarSummaryView {
            let view = SimilarSummaryView()
            view.configure(setsToCheck: 6, done: 2, bytesToFree: 73_000_000)
            return view
        }

        func updateUIView(_ uiView: SimilarSummaryView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview {
        SimilarSummaryPreview()
            .frame(height: 20)
            .padding()
            .background(Color(.systemGroupedBackground))
    }
#endif
