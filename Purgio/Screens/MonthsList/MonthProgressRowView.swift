//
//  MonthProgressRowView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 16.11.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static let done = NSLocalizedString("monthCell.done", comment: "Pill on a fully reviewed month row")
    static let allCaughtUp = NSLocalizedString("monthCell.allCaughtUp", comment: "All caught up message")

    static func leftCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("monthCell.leftCount", comment: "Items left to review: 8 left"), count)
    }

    /// The word of `leftCount` without its number ("left"), for under the large number
    static func leftCaption(_ count: Int) -> String {
        let number = String.localizedStringWithFormat("%lld", count)
        return leftCount(count)
            .replacingOccurrences(of: number, with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    static func accessibilityReviewed(_ reviewed: Int, _ total: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "monthCell.accessibilityReviewed", comment: "VoiceOver: 1 is the reviewed count, 2 the total"),
            reviewed, total)
    }
}

/// The months list's row (board PM3): a review capsule, the title over a subtitle for the row's
/// state, and the number left (or a Done pill). Month and sparse-year cells share it.
final class MonthProgressRowView: UIView {

    private enum Layout {
        static let minimumHeight: CGFloat = 64
        static let verticalPadding: CGFloat = 12
        /// The capsule's 12pt plus 6pt on each side; the finished check overflows into the sides
        static let capsuleSlotWidth: CGFloat = 24
        /// From the slot's trailing edge to the text, on top of the slot's own 6pt
        static let slotToText: CGFloat = 12
        static let titleFontSize: CGFloat = 17
        static let textSpacing: CGFloat = 3
        static let textToValue: CGFloat = 10
        static let subtitleFontSize: CGFloat = 13
        static let chipFontSize: CGFloat = 12
        static let chipIconPointSize: CGFloat = 12
        static let chipSpacing: CGFloat = 10
        static let chipLineSpacing: CGFloat = 3
        static let numberFontSize: CGFloat = 20
        static let captionFontSize: CGFloat = 12
        static let pillHeight: CGFloat = 26
        static let pillSideInset: CGFloat = 10
        static let pillIconPadding: CGFloat = 4
        static let pillFontSize: CGFloat = 13
        static let pillIconPointSize: CGFloat = 12
        static let pillTintAlpha: CGFloat = 0.15
        static let glyphPointSize: CGFloat = 14
        static let glyphSpacing: CGFloat = 6
    }

    private struct ChipCounts {
        let deleted: Int
        let kept: Int
        let stored: Int
    }

    /// What VoiceOver reads for the whole row
    private(set) var accessibilitySummary: String = ""

    /// Kept to rebuild the chips when the appearance changes (their icons bake their color)
    private var chipCounts: ChipCounts?

    private let capsuleSlot: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let capsuleView: ReviewCapsuleView = {
        let view = ReviewCapsuleView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.titleFont(size: Layout.titleFontSize, weight: .semibold)
        label.textColor = .textPrimary
        label.numberOfLines = 1
        return label
    }()

    /// Optional photo / video mark after the title, for lists that mix both media types
    private let glyphView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }()

    private let titleRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Layout.glyphSpacing
        return stack
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Layout.subtitleFontSize, weight: .regular)
        label.textColor = .textSecondary
        label.numberOfLines = 0
        return label
    }()

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Layout.textSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let numberLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: Layout.numberFontSize, weight: .bold)
        label.textColor = .label
        label.textAlignment = .natural
        return label
    }()

    private let leftLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Layout.captionFontSize, weight: .regular)
        label.textColor = .textSecondary
        return label
    }()

    /// Decorative: it only looks like a button
    private let donePill: UIButton = {
        let green = ThemeManager.Colors.statusGreen
        var config = UIButton.Configuration.plain()
        config.cornerStyle = .capsule
        config.background.backgroundColor = UIColor { traits in
            green.resolvedColor(with: traits).withAlphaComponent(Layout.pillTintAlpha)
        }
        config.image = UIImage(
            systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Layout.pillIconPointSize, weight: .bold))
        config.imagePadding = Layout.pillIconPadding
        config.baseForegroundColor = green
        config.attributedTitle = AttributedString(
            Strings.done,
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: Layout.pillFontSize, weight: .semibold)]))
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 0, leading: Layout.pillSideInset, bottom: 0, trailing: Layout.pillSideInset)

        let button = UIButton(configuration: config)
        button.isUserInteractionEnabled = false
        button.isAccessibilityElement = false
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let valueStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .trailing
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Init

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
        addSubview(capsuleSlot)
        capsuleSlot.addSubview(capsuleView)

        // The glyph follows the title's text; the spacer takes the rest of the row
        let titleRowSpacer = UIView()
        titleRowSpacer.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        titleRowSpacer.setContentCompressionResistancePriority(UILayoutPriority(1), for: .horizontal)
        titleRow.addArrangedSubview(titleLabel)
        titleRow.addArrangedSubview(glyphView)
        titleRow.addArrangedSubview(titleRowSpacer)
        textStack.addArrangedSubview(titleRow)
        textStack.addArrangedSubview(subtitleLabel)
        addSubview(textStack)

        valueStack.addArrangedSubview(numberLabel)
        valueStack.addArrangedSubview(leftLabel)
        valueStack.addArrangedSubview(donePill)
        addSubview(valueStack)

        // The text column gives way first; the number, the pill and the capsule never shrink
        [titleLabel, subtitleLabel].forEach {
            $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            $0.setContentHuggingPriority(.defaultLow, for: .horizontal)
        }
        [numberLabel, leftLabel, donePill, valueStack].forEach {
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            $0.setContentHuggingPriority(.required, for: .horizontal)
        }
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: MonthProgressRowView, _: UITraitCollection) in
                self.refreshChips()
            }
        }
        reset()
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.minimumHeight),

            capsuleSlot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: GeneralConstants.EdgePadding.small),
            capsuleSlot.widthAnchor.constraint(equalToConstant: Layout.capsuleSlotWidth),
            capsuleSlot.centerYAnchor.constraint(equalTo: centerYAnchor),
            capsuleSlot.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: Layout.verticalPadding),
            capsuleSlot.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Layout.verticalPadding),

            capsuleView.centerXAnchor.constraint(equalTo: capsuleSlot.centerXAnchor),
            capsuleView.topAnchor.constraint(equalTo: capsuleSlot.topAnchor),
            capsuleView.bottomAnchor.constraint(equalTo: capsuleSlot.bottomAnchor),
            capsuleView.widthAnchor.constraint(equalToConstant: capsuleView.intrinsicContentSize.width),
            capsuleView.heightAnchor.constraint(equalToConstant: capsuleView.intrinsicContentSize.height),

            textStack.leadingAnchor.constraint(equalTo: capsuleSlot.trailingAnchor, constant: Layout.slotToText),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: Layout.verticalPadding),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Layout.verticalPadding),
            textStack.trailingAnchor.constraint(equalTo: valueStack.leadingAnchor, constant: -Layout.textToValue),

            valueStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -GeneralConstants.EdgePadding.small),
            valueStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: Layout.verticalPadding),
            valueStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Layout.verticalPadding),

            donePill.heightAnchor.constraint(equalToConstant: Layout.pillHeight)
        ])
    }

    // MARK: - Configure

    /// `total` is the row's total (`originalTotalCount`, else the live count). The row is finished
    /// when `total > 0 && reviewed >= total` and not started while `reviewed` is 0.
    /// `notStartedSubtitle` is the cell's own text for a row nobody has touched yet.
    /// `mediaGlyph` shows a photo or video mark before the title (off by default).
    func configure(
        title: String,
        titleFont: UIFont = ThemeManager.Fonts.titleFont(size: Layout.titleFontSize, weight: .semibold),
        deleted: Int,
        kept: Int,
        stored: Int,
        total: Int,
        reviewed: Int,
        notStartedSubtitle: String,
        mediaGlyph: PHAssetMediaType? = nil
    ) {
        titleLabel.text = title
        applyGlyph(mediaGlyph)
        titleLabel.font = titleFont
        capsuleView.configure(deleted: deleted, kept: kept, stored: stored, total: total, reviewed: reviewed)

        if total > 0 && reviewed >= total {
            chipCounts = nil
            subtitleLabel.attributedText = NSAttributedString(
                string: Strings.allCaughtUp,
                attributes: [
                    .foregroundColor: ThemeManager.Colors.statusGreen,
                    .font: UIFont.systemFont(ofSize: Layout.subtitleFontSize, weight: .medium)
                ])
            showValue(left: nil)
            accessibilitySummary = [title, Strings.allCaughtUp].joined(separator: ", ")
        } else if reviewed <= 0 {
            chipCounts = nil
            subtitleLabel.attributedText = NSAttributedString(
                string: notStartedSubtitle,
                attributes: [
                    .foregroundColor: UIColor.textSecondary,
                    .font: UIFont.systemFont(ofSize: Layout.subtitleFontSize, weight: .regular)
                ])
            showValue(left: total)
            accessibilitySummary = [title, notStartedSubtitle].joined(separator: ", ")
        } else {
            let counts = clampedCounts(deleted: deleted, kept: kept, stored: stored, reviewed: reviewed)
            chipCounts = counts
            subtitleLabel.attributedText = chipsText(for: counts)
            let left = max(0, total - reviewed)
            showValue(left: left)
            accessibilitySummary = [
                title, Strings.accessibilityReviewed(reviewed, total), Strings.leftCount(left)
            ].joined(separator: ", ")
        }
    }

    /// Clears everything, so a recycled cell never shows the previous row's state
    func reset() {
        chipCounts = nil
        titleLabel.text = nil
        applyGlyph(nil)
        subtitleLabel.attributedText = nil
        numberLabel.text = nil
        leftLabel.text = nil
        numberLabel.isHidden = false
        leftLabel.isHidden = false
        donePill.isHidden = true
        capsuleView.reset()
        accessibilitySummary = ""
    }

    private func applyGlyph(_ mediaType: PHAssetMediaType?) {
        guard let mediaType else {
            glyphView.isHidden = true
            glyphView.image = nil
            return
        }
        let isVideo = mediaType == .video
        glyphView.image = UIImage(
            systemName: isVideo ? "video.fill" : "photo.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Layout.glyphPointSize, weight: .semibold))
        glyphView.tintColor = .textTertiary
        glyphView.isHidden = false
    }

    /// The number left over its caption, or the Done pill when `left` is nil
    private func showValue(left: Int?) {
        let isFinished = left == nil
        numberLabel.isHidden = isFinished
        leftLabel.isHidden = isFinished
        donePill.isHidden = !isFinished
        guard let left else { return }
        numberLabel.text = left.compactFormatted
        leftLabel.text = Strings.leftCaption(left)
    }

    /// Delete + keep + store never add up to more than what was reviewed
    private func clampedCounts(deleted: Int, kept: Int, stored: Int, reviewed: Int) -> ChipCounts {
        let deleted = max(0, deleted)
        let kept = max(0, kept)
        let stored = max(0, stored)
        let decided = deleted + kept + stored
        guard decided > reviewed, decided > 0 else {
            return ChipCounts(deleted: deleted, kept: kept, stored: stored)
        }
        let scale = Double(reviewed) / Double(decided)
        return ChipCounts(
            deleted: Int(Double(deleted) * scale),
            kept: Int(Double(kept) * scale),
            stored: Int(Double(stored) * scale))
    }

    // MARK: - Chips

    /// "trash 20  checkmark 38  archivebox 5" as one wrapping text: a chip's icon and count stay
    /// together, and a line only breaks between chips, so a count is never truncated.
    private func chipsText(for counts: ChipCounts) -> NSAttributedString {
        var chips: [(systemName: String, color: UIColor, count: Int)] = [
            ("trash.fill", ThemeManager.Colors.statusRed, counts.deleted),
            ("checkmark.circle.fill", ThemeManager.Colors.statusGreen, counts.kept),
            ("archivebox.fill", ThemeManager.Colors.statusYellow, counts.stored)
        ].filter { $0.count > 0 }
        if chips.isEmpty {
            chips = [("trash.fill", ThemeManager.Colors.statusRed, 0)]
        }

        let font = UIFont.monospacedDigitSystemFont(ofSize: Layout.chipFontSize, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = Layout.chipLineSpacing
        paragraph.lineBreakMode = .byWordWrapping
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.textSecondary,
            .paragraphStyle: paragraph
        ]
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        var gapAttributes = textAttributes
        gapAttributes[.kern] = Layout.chipSpacing - spaceWidth

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: Layout.chipIconPointSize, weight: .semibold)
        let result = NSMutableAttributedString()
        for (index, chip) in chips.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: " ", attributes: gapAttributes))
            }
            if let image = UIImage(systemName: chip.systemName, withConfiguration: symbolConfig)?
                .withTintColor(chip.color.resolvedColor(with: traitCollection), renderingMode: .alwaysOriginal)
            {
                let attachment = NSTextAttachment()
                attachment.image = image
                attachment.bounds = CGRect(
                    x: 0, y: (font.capHeight - image.size.height) / 2,
                    width: image.size.width, height: image.size.height)
                let icon = NSMutableAttributedString(attachment: attachment)
                icon.addAttributes(textAttributes, range: NSRange(location: 0, length: icon.length))
                result.append(icon)
                // No-break space: the icon stays with its count
                result.append(NSAttributedString(string: "\u{00A0}", attributes: textAttributes))
            }
            result.append(NSAttributedString(string: chip.count.compactFormatted, attributes: textAttributes))
        }
        return result
    }

    private func refreshChips() {
        guard let chipCounts else { return }
        subtitleLabel.attributedText = chipsText(for: chipCounts)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshChips()
        }
    }
}
