//
//  HomeResumeSectionView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 18.11.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static let sectionTitle = NSLocalizedString(
        "home.resumeTitle", comment: "Home section title over in-progress months and years")
    static let startTitle = NSLocalizedString(
        "home.startReviewing", comment: "Home section title over months not started yet (nothing in progress)")
    static let photos = NSLocalizedString("home.photosTitle", comment: "Photos section title")
    static let videos = NSLocalizedString("home.videosTitle", comment: "Videos section title")

    static func photosToReview(_ count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("home.photosToReview", comment: "Home row: photos to review count"), count)
    }

    static func videosToReview(_ count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("home.videosToReview", comment: "Home row: videos to review count"), count)
    }

    static func itemsCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("home.itemsCount", comment: "Home row: a sparse year's item count"), count)
    }
}

/// One in-progress month or sparse year on Home
struct HomeResumeItem: Equatable {
    /// A month key (`yyyy-MM`) or a year key (`year-YYYY`)
    let key: String
    let mediaType: PHAssetMediaType
    let title: String
    let isYear: Bool
    let deleted: Int
    let kept: Int
    let stored: Int
    let total: Int
    let reviewed: Int
    /// The year's months, so the hub's year details work as they do from the months list
    let yearMonths: [MonthItem]

    static func == (lhs: HomeResumeItem, rhs: HomeResumeItem) -> Bool {
        lhs.key == rhs.key && lhs.mediaType == rhs.mediaType && lhs.title == rhs.title
            && lhs.deleted == rhs.deleted && lhs.kept == rhs.kept && lhs.stored == rhs.stored
            && lhs.total == rhs.total && lhs.reviewed == rhs.reviewed
    }
}

/// Home's "Continue Where You Left Off": a section title over one card of month rows
/// (`MonthProgressRowView`, as in the months list), separated by hairlines. Home decides how
/// many rows fit; the section never scrolls. With nothing in progress Home hands it months
/// not started yet instead, and the title becomes "Start Reviewing".
final class HomeResumeSectionView: UIView {

    static let maximumRowCount = 4

    private enum Layout {
        static let titleToCard: CGFloat = 8
        static let titleFontSize: CGFloat = 13
    }

    var onSelect: ((HomeResumeItem) -> Void)?

    /// The rounded card, for `updateCardCorners(followingDeviceCorner:)`
    var cardView: UIView { card }

    private(set) var items: [HomeResumeItem] = []
    private(set) var visibleRowCount = 0

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.sectionTitle
        label.font = ThemeManager.Fonts.titleFont(size: Layout.titleFontSize, weight: .semibold)
        label.textColor = .textSecondary
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.accessibilityTraits = .header
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let card: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        view.layer.cornerRadius = GeneralConstants.CornerRadius.card
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let rowsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let rows: [HomeResumeRowControl] = (0..<HomeResumeSectionView.maximumRowCount).map { _ in
        HomeResumeRowControl()
    }

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
        addSubview(titleLabel)
        addSubview(card)
        card.addSubview(rowsStack)

        rows.enumerated().forEach { index, row in
            row.isHidden = true
            row.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
            row.tag = index
            rowsStack.addArrangedSubview(row)
        }

        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func setupConstraint() {
        let compressedHeight = heightAnchor.constraint(equalToConstant: 0)
        compressedHeight.priority = UILayoutPriority(UILayoutPriority.defaultLow.rawValue + 1)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),

            card.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Layout.titleToCard),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),

            rowsStack.topAnchor.constraint(equalTo: card.topAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            // Stays at its rows' height: the stack it sits in gives spare room to its neighbours
            compressedHeight
        ])
    }

    // MARK: - Configure

    /// Keeps the first `maximumRowCount` items; `setVisibleRowCount(_:)` decides how many show.
    func configure(items: [HomeResumeItem]) {
        self.items = Array(items.prefix(Self.maximumRowCount))
        // In-progress rows always have something reviewed; a list of none is the start list
        titleLabel.text = !self.items.isEmpty && self.items.allSatisfy { $0.reviewed == 0 }
            ? Strings.startTitle
            : Strings.sectionTitle
        for (index, row) in rows.enumerated() {
            if index < self.items.count {
                row.configure(with: self.items[index])
            } else {
                row.reset()
            }
        }
        setVisibleRowCount(min(visibleRowCount, self.items.count))
    }

    func setVisibleRowCount(_ count: Int) {
        visibleRowCount = max(0, min(count, items.count))
        for (index, row) in rows.enumerated() {
            let isVisible = index < visibleRowCount
            if row.isHidden == isVisible { row.isHidden = !isVisible }
            row.showsSeparator = index > 0
        }
    }

    // MARK: - Measuring

    /// The title and its gap to the card, at this width
    func headerHeight(fittingWidth width: CGFloat) -> CGFloat {
        let size = titleLabel.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel)
        return ceil(size.height) + Layout.titleToCard
    }

    /// Each configured row's height at this width (a row's chips can wrap to a second line)
    func rowHeights(fittingWidth width: CGFloat) -> [CGFloat] {
        rows.prefix(items.count).map { row in
            let size = row.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel)
            return ceil(size.height)
        }
    }

    // MARK: - Actions

    @objc private func rowTapped(_ sender: HomeResumeRowControl) {
        guard items.indices.contains(sender.tag) else { return }
        onSelect?(items[sender.tag])
    }
}

// MARK: - Row

/// A month row plus its chevron, as in the months list's cells, with a hairline above it
private final class HomeResumeRowControl: UIControl {

    var showsSeparator = false {
        didSet { separator.isHidden = !showsSeparator }
    }

    private let rowView: MonthProgressRowView = {
        let view = MonthProgressRowView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let chevronImageView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        imageView.image = UIImage(systemName: "chevron.right", withConfiguration: config)
        imageView.tintColor = .textTertiary
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let separator: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        view.isHidden = true
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var separatorHeightConstraint: NSLayoutConstraint?

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.alpha = self.isHighlighted ? 0.8 : 1.0
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(rowView)
        addSubview(chevronImageView)
        addSubview(separator)

        isAccessibilityElement = true
        accessibilityTraits = .button

        let separatorHeight = separator.heightAnchor.constraint(equalToConstant: 1)
        separatorHeightConstraint = separatorHeight

        NSLayoutConstraint.activate([
            rowView.topAnchor.constraint(equalTo: topAnchor),
            rowView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowView.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor),
            rowView.bottomAnchor.constraint(equalTo: bottomAnchor),

            chevronImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20),

            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorHeight
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let hairline = 1 / max(traitCollection.displayScale, 1)
        if separatorHeightConstraint?.constant != hairline {
            separatorHeightConstraint?.constant = hairline
        }
    }

    func configure(with item: HomeResumeItem) {
        rowView.configure(
            title: item.title,
            titleFont: item.isYear
                ? ThemeManager.Fonts.titleFont(size: 17, weight: .bold)
                : ThemeManager.Fonts.titleFont(size: 17, weight: .semibold),
            deleted: item.deleted,
            kept: item.kept,
            stored: item.stored,
            total: item.total,
            reviewed: item.reviewed,
            notStartedSubtitle: notStartedSubtitle(for: item),
            mediaGlyph: item.mediaType)
        let mediaName = item.mediaType == .video ? Strings.videos : Strings.photos
        accessibilityLabel = [rowView.accessibilitySummary, mediaName].joined(separator: ", ")
    }

    /// "312 photos to review", or a sparse year's "23 items"
    private func notStartedSubtitle(for item: HomeResumeItem) -> String {
        if item.isYear { return Strings.itemsCount(item.total) }
        return item.mediaType == .video ? Strings.videosToReview(item.total) : Strings.photosToReview(item.total)
    }

    func reset() {
        rowView.reset()
        accessibilityLabel = nil
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
#Preview(traits: .fixedLayout(width: 402, height: 420)) {
    let container = UIView()
    container.backgroundColor = .mainBackground
    let section = HomeResumeSectionView()
    section.translatesAutoresizingMaskIntoConstraints = false
    section.configure(items: [
        HomeResumeItem(
            key: "2026-10", mediaType: .image, title: "October 2026", isYear: false,
            deleted: 12, kept: 28, stored: 6, total: 88, reviewed: 46, yearMonths: []),
        HomeResumeItem(
            key: "2026-10", mediaType: .video, title: "October 2026", isYear: false,
            deleted: 3, kept: 8, stored: 1, total: 28, reviewed: 12, yearMonths: []),
        HomeResumeItem(
            key: "year-2015", mediaType: .image, title: "2015", isYear: true,
            deleted: 4, kept: 2, stored: 0, total: 31, reviewed: 6, yearMonths: [])
    ])
    section.setVisibleRowCount(3)
    container.addSubview(section)
    NSLayoutConstraint.activate([
        section.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
        section.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
        section.topAnchor.constraint(equalTo: container.topAnchor, constant: 20)
    ])
    return container
}
#endif
