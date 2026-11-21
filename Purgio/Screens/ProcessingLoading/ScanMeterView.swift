//
//  ScanMeterView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 22.11.2026.
//

import UIKit

/// What the filter loading screen's meter shows.
struct ScanMeterState {
    /// Items checked so far; nil before the first result (the starting state).
    var checked: Int?
    /// How many of the checked items the filter turned up.
    var found: Int = 0
    /// Items to check; nil until the month is fetched.
    var total: Int?
    /// The finds row's name: "Found", "Over 60 MB".
    var findsTitle: String
    /// The line under the meter: the time left, "Getting photos ready", "Opening the first photo…".
    var footnote: String
    /// The same line spelled out for VoiceOver ("about 8 seconds left").
    var footnoteAccessibility: String
}

/// The filter loading screen's meter: a `ScanCapsuleView` and, beside it, the percent, the
/// checked count and a three-row legend (finds, checked, left), with one line under them.
/// One VoiceOver element. `isCompact` is the short-column variant (iPhone SE, the cover display).
final class ScanMeterView: UIView {

    private enum Layout {
        struct Metrics {
            let capsuleSize: CGSize
            let capsuleToStats: CGFloat
            let statsWidth: CGFloat
            let percentFontSize: CGFloat
            let countToLegend: CGFloat
            let legendSpacing: CGFloat
            let meterToFootnote: CGFloat
        }

        static let regular = Metrics(
            capsuleSize: CGSize(width: 60, height: 250), capsuleToStats: 34, statsWidth: 170,
            percentFontSize: 56, countToLegend: 21, legendSpacing: 9, meterToFootnote: 24)
        static let compact = Metrics(
            capsuleSize: CGSize(width: 44, height: 170), capsuleToStats: 24, statsWidth: 150,
            percentFontSize: 42, countToLegend: 14, legendSpacing: 7, meterToFootnote: 14)

        static let percentToCount: CGFloat = 6
        static let countFontSize: CGFloat = 14
        static let footnoteFontSize: CGFloat = 14
        static let placeholder = "–"
    }

    /// The short-column variant: a smaller capsule and percent, tighter gaps.
    var isCompact = false {
        didSet {
            guard isCompact != oldValue else { return }
            applyMetrics()
        }
    }

    private var state: ScanMeterState?

    // MARK: - Views

    private let capsuleView: ScanCapsuleView = {
        let view = ScanCapsuleView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let percentLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        return label
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: Layout.countFontSize, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let foundRow = LegendRow(markColor: .systemBlue)
    private let checkedRow = LegendRow(markColor: .label)
    private let leftRow = LegendRow(markColor: .systemGray5)

    private let legendStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        return stack
    }()

    private let statsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let meterRowStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        return stack
    }()

    private let footnoteLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Layout.footnoteFontSize)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var capsuleWidthConstraint: NSLayoutConstraint?
    private var capsuleHeightConstraint: NSLayoutConstraint?
    private var statsWidthConstraint: NSLayoutConstraint?

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
        applyMetrics()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        isAccessibilityElement = true
        accessibilityTraits = .updatesFrequently

        checkedRow.setTitle(Strings.legendChecked)
        leftRow.setTitle(Strings.legendLeft)
        [foundRow, checkedRow, leftRow].forEach { legendStack.addArrangedSubview($0) }

        statsStack.addArrangedSubview(percentLabel)
        statsStack.addArrangedSubview(countLabel)
        statsStack.addArrangedSubview(legendStack)
        statsStack.setCustomSpacing(Layout.percentToCount, after: percentLabel)

        meterRowStack.addArrangedSubview(capsuleView)
        meterRowStack.addArrangedSubview(statsStack)

        contentStack.addArrangedSubview(meterRowStack)
        contentStack.addArrangedSubview(footnoteLabel)
        addSubview(contentStack)
    }

    private func setupConstraint() {
        let capsuleWidth = capsuleView.widthAnchor.constraint(equalToConstant: Layout.regular.capsuleSize.width)
        let capsuleHeight = capsuleView.heightAnchor.constraint(equalToConstant: Layout.regular.capsuleSize.height)
        let statsWidth = statsStack.widthAnchor.constraint(equalToConstant: Layout.regular.statsWidth)
        capsuleWidthConstraint = capsuleWidth
        capsuleHeightConstraint = capsuleHeight
        statsWidthConstraint = statsWidth

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            capsuleWidth,
            capsuleHeight,
            statsWidth,
            // A definite width, so the line wraps inside the meter's own width and never keeps
            // a narrower one from an earlier layout
            footnoteLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor)
        ])
    }

    private func applyMetrics() {
        let metrics = isCompact ? Layout.compact : Layout.regular
        capsuleWidthConstraint?.constant = metrics.capsuleSize.width
        capsuleHeightConstraint?.constant = metrics.capsuleSize.height
        statsWidthConstraint?.constant = metrics.statsWidth
        meterRowStack.spacing = metrics.capsuleToStats
        statsStack.setCustomSpacing(metrics.countToLegend, after: countLabel)
        legendStack.spacing = metrics.legendSpacing
        contentStack.spacing = metrics.meterToFootnote
        percentLabel.font = .monospacedDigitSystemFont(ofSize: metrics.percentFontSize, weight: .heavy)
    }

    // MARK: - Update

    func update(with state: ScanMeterState, animated: Bool) {
        self.state = state
        foundRow.setTitle(state.findsTitle)
        footnoteLabel.text = state.footnote

        guard let checked = state.checked, let total = state.total else {
            // Starting: nothing checked yet
            capsuleView.configure(checked: 0, found: 0, total: state.total ?? 0, animated: false)
            percentLabel.text = Layout.placeholder
            countLabel.text = state.total.map { Strings.checkedCountPending(total: $0) }
                ?? "\(Layout.placeholder) / \(Layout.placeholder)"
            [foundRow, checkedRow, leftRow].forEach { $0.setCount(Layout.placeholder) }
            accessibilityLabel = state.footnoteAccessibility
            accessibilityValue = nil
            return
        }

        let found = max(0, min(state.found, checked))
        capsuleView.configure(checked: checked, found: found, total: total, animated: animated)
        let percent = Self.percentText(checked: checked, total: total)
        percentLabel.text = percent
        countLabel.text = Strings.checkedCount(checked: checked, total: total)
        foundRow.setCount("\(found)")
        checkedRow.setCount("\(checked - found)")
        leftRow.setCount("\(max(0, total - checked))")
        accessibilityLabel = Strings.meterAccessibility(
            percent: percent, checked: checked, total: total, found: found,
            footnote: state.footnoteAccessibility)
        accessibilityValue = nil
    }

    /// "40%", or "%40" in Turkish; 1…99 while some but not all is checked.
    static func percentText(checked: Int, total: Int) -> String {
        let percent = checked.roundedPercent(of: total)
        return percentFormatter.string(from: NSNumber(value: Double(percent) / 100)) ?? "\(percent)%"
    }
}

// MARK: - Legend row

/// A capsule mark, the name and its count trailing.
private final class LegendRow: UIView {

    private enum Layout {
        static let markSize = CGSize(width: 6, height: 14)
        static let markToName: CGFloat = 10
        static let fontSize: CGFloat = 15
    }

    private let markView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = Layout.markSize.width / 2
        view.layer.cornerCurve = .continuous
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: Layout.fontSize)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: Layout.fontSize, weight: .bold)
        label.textColor = .label
        label.textAlignment = .natural
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    init(markColor: UIColor) {
        super.init(frame: .zero)
        markView.backgroundColor = markColor
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(markView)
        addSubview(titleLabel)
        addSubview(countLabel)

        NSLayoutConstraint.activate([
            markView.leadingAnchor.constraint(equalTo: leadingAnchor),
            markView.centerYAnchor.constraint(equalTo: centerYAnchor),
            markView.widthAnchor.constraint(equalToConstant: Layout.markSize.width),
            markView.heightAnchor.constraint(equalToConstant: Layout.markSize.height),
            heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.markSize.height),

            titleLabel.leadingAnchor.constraint(equalTo: markView.trailingAnchor, constant: Layout.markToName),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),

            countLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: Layout.markToName),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            countLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor)
        ])
    }

    func setTitle(_ title: String) {
        guard titleLabel.text != title else { return }
        titleLabel.text = title
    }

    func setCount(_ count: String) {
        guard countLabel.text != count else { return }
        countLabel.text = count
    }
}

// MARK: - Strings

private enum Strings {
    static let legendChecked = NSLocalizedString("processing.legendChecked", comment: "Meter legend: items checked without a find")
    static let legendLeft = NSLocalizedString("processing.legendLeft", comment: "Meter legend: items still to check")

    static func checkedCount(checked: Int, total: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("processing.checkedCount", comment: "Checked so far, e.g. '23 / 57 checked'"),
            checked, total)
    }

    static func checkedCountPending(total: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("processing.checkedCountPending", comment: "Before the first result, e.g. '– / 57 checked'"),
            total)
    }

    static func meterAccessibility(percent: String, checked: Int, total: Int, found: Int, footnote: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "processing.meterAccessibility",
                comment: "VoiceOver: percent, checked of total, found, time left"),
            percent, checked, total, found, footnote)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

private struct ScanMeterPreview: UIViewRepresentable {
    let state: ScanMeterState
    var isCompact = false

    func makeUIView(context: Context) -> ScanMeterView {
        let view = ScanMeterView()
        view.isCompact = isCompact
        view.update(with: state, animated: false)
        return view
    }

    func updateUIView(_ uiView: ScanMeterView, context: Context) {}
}

@available(iOS 17.0, *)
#Preview("Checking") {
    ScanMeterPreview(state: ScanMeterState(
        checked: 23, found: 3, total: 57, findsTitle: "Found",
        footnote: "About 8 s left", footnoteAccessibility: "about 8 seconds left"))
        .fixedSize()
}

@available(iOS 17.0, *)
#Preview("Starting, compact") {
    ScanMeterPreview(
        state: ScanMeterState(
            checked: nil, total: 57, findsTitle: "Found",
            footnote: "Getting photos ready", footnoteAccessibility: "Getting photos ready"),
        isCompact: true)
        .fixedSize()
}
#endif
