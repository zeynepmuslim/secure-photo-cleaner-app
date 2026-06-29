//
//  YearDetailSheet.swift
//  Purgio
//
//  Created by ZeynepMüslim on 25.06.2026.
//

import Photos
import SwiftUI
import UIKit

// MARK: - Strings
private enum Strings {
    static func monthsCount(_ n: Int) -> String {
        String(format: NSLocalizedString("yearDetailSheet.months", comment: ""), n)
    }
    static func itemsCount(_ n: Int) -> String {
        String(format: NSLocalizedString("yearCell.itemsCount", comment: ""), n)
    }
}

// MARK: - YearDetailSheet
final class YearDetailSheet: UIViewController {

    private let yearItem: YearItem

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.titleFont(size: 24, weight: .bold)
        label.textColor = .textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let headerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let headerSeparator: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Init
    init(yearItem: YearItem) {
        self.yearItem = yearItem
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        configureSheet()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Configuration
    private func configureSheet() {
        guard let sheet = sheetPresentationController else { return }
        if #available(iOS 16.0, *) {
            let custom = UISheetPresentationController.Detent.custom { context in
                context.maximumDetentValue * 0.60
            }
            sheet.detents = [custom, .large()]
        } else {
            sheet.detents = [.medium(), .large()]
        }
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .mainBackground
        setupViews()
        setupConstraints()
        buildMonthRows()
    }

    // MARK: - Setup
    private func setupViews() {
        titleLabel.text = yearItem.year
        subtitleLabel.text = "\(Strings.monthsCount(yearItem.months.count)) · \(Strings.itemsCount(yearItem.currentTotalCount))"

        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(subtitleLabel)

        view.addSubview(headerStack)
        view.addSubview(headerSeparator)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            headerSeparator.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            headerSeparator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerSeparator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            scrollView.topAnchor.constraint(equalTo: headerSeparator.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func buildMonthRows() {
        for (index, month) in yearItem.months.enumerated() {
            let row = MonthDetailRowView(month: month, mediaType: yearItem.mediaType)
            contentStack.addArrangedSubview(row)

            if index < yearItem.months.count - 1 {
                let sep = makeSeparator()
                contentStack.addArrangedSubview(sep)
                sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
            }
        }
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(spacer)
        spacer.heightAnchor.constraint(equalToConstant: 20).isActive = true
    }

    private func makeSeparator() -> UIView {
        let view = UIView()
        view.backgroundColor = .separator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
}

// MARK: - MonthDetailRowView
private final class MonthDetailRowView: UIView {
    private let monthNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let percentLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .textSecondary
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let barBackground: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        view.layer.cornerRadius = 1.5
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let barFill: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 1.5
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var fillWidthConstraint: NSLayoutConstraint?

    init(month: MonthItem, mediaType: PHAssetMediaType) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupLayout()
        configure(with: month, mediaType: mediaType)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupLayout() {
        addSubview(monthNameLabel)
        addSubview(countLabel)
        addSubview(percentLabel)
        addSubview(barBackground)
        barBackground.addSubview(barFill)

        NSLayoutConstraint.activate([
            monthNameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            monthNameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            monthNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: percentLabel.leadingAnchor, constant: -8),

            percentLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            percentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            percentLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),

            countLabel.topAnchor.constraint(equalTo: monthNameLabel.bottomAnchor, constant: 2),
            countLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            barBackground.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 8),
            barBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            barBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            barBackground.heightAnchor.constraint(equalToConstant: 3),
            barBackground.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),

            barFill.topAnchor.constraint(equalTo: barBackground.topAnchor),
            barFill.bottomAnchor.constraint(equalTo: barBackground.bottomAnchor),
            barFill.leadingAnchor.constraint(equalTo: barBackground.leadingAnchor),
        ])
    }

    private func configure(with month: MonthItem, mediaType: PHAssetMediaType) {
        monthNameLabel.text = month.title

        let count = month.currentPhotoCount
        countLabel.text = String(format: NSLocalizedString("yearCell.itemsCount", comment: ""), count)

        let total = month.originalTotalCount > 0 ? month.originalTotalCount : month.currentPhotoCount
        let pct = total > 0 ? Int(Double(month.reviewedCount) / Double(total) * 100) : 0

        if pct >= 100 {
            let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            let image = UIImage(systemName: "checkmark", withConfiguration: config)?
                .withTintColor(ThemeManager.Colors.statusGreen, renderingMode: .alwaysOriginal)
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(x: 0, y: -1, width: 12, height: 12)
            percentLabel.attributedText = NSAttributedString(attachment: attachment)
            percentLabel.textColor = ThemeManager.Colors.statusGreen
        } else {
            percentLabel.text = "\(pct)%"
            percentLabel.textColor = .textSecondary
        }

        barFill.backgroundColor = mediaType == .video ? .video50 : .photo50

        let fraction = max(CGFloat(pct) / 100.0, 0.001)
        fillWidthConstraint?.isActive = false
        fillWidthConstraint = barFill.widthAnchor.constraint(
            equalTo: barBackground.widthAnchor, multiplier: fraction)
        fillWidthConstraint?.isActive = true
    }
}

@available(iOS 17.0, *)
#Preview("In Progress") {
    YearDetailSheet(yearItem: YearItem(
        year: "2015", key: "year-2015",
        months: [
            MonthItem(title: "January 2015",  key: "2015-01", currentPhotoCount: 5, reviewedCount: 3, keptCount: 2, deletedCount: 1, storedCount: 0, originalTotalCount: 5, mediaType: .image),
            MonthItem(title: "March 2015",    key: "2015-03", currentPhotoCount: 8, reviewedCount: 0, keptCount: 0, deletedCount: 0, storedCount: 0, originalTotalCount: 8, mediaType: .image),
            MonthItem(title: "July 2015",     key: "2015-07", currentPhotoCount: 6, reviewedCount: 6, keptCount: 4, deletedCount: 2, storedCount: 0, originalTotalCount: 6, mediaType: .image),
            MonthItem(title: "November 2015", key: "2015-11", currentPhotoCount: 4, reviewedCount: 2, keptCount: 1, deletedCount: 1, storedCount: 0, originalTotalCount: 4, mediaType: .image),
        ],
        currentTotalCount: 23, reviewedCount: 11, deletedCount: 4, keptCount: 7, storedCount: 0, originalTotalCount: 23, mediaType: .image))
}

@available(iOS 17.0, *)
#Preview("Not Started") {
    YearDetailSheet(yearItem: YearItem(
        year: "2019", key: "year-2019",
        months: [
            MonthItem(title: "April 2019", key: "2019-04", currentPhotoCount: 12, reviewedCount: 0, keptCount: 0, deletedCount: 0, storedCount: 0, originalTotalCount: 12, mediaType: .image),
            MonthItem(title: "August 2019", key: "2019-08", currentPhotoCount: 9,  reviewedCount: 0, keptCount: 0, deletedCount: 0, storedCount: 0, originalTotalCount: 9,  mediaType: .image),
        ],
        currentTotalCount: 21, reviewedCount: 0, deletedCount: 0, keptCount: 0, storedCount: 0, originalTotalCount: 21, mediaType: .image))
}
