//
//  MonthStatItemView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 24.02.2026.
//

import UIKit

final class MonthStatItemView: UIView {

    private let dotView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.titleFont(size: 18, weight: .bold)
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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
        addSubview(dotView)
        addSubview(valueLabel)
        addSubview(titleLabel)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            dotView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            dotView.centerXAnchor.constraint(equalTo: centerXAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 8),
            dotView.heightAnchor.constraint(equalToConstant: 8),

            valueLabel.topAnchor.constraint(equalTo: dotView.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func configure(title: String, color: UIColor) {
        titleLabel.text = title
        dotView.backgroundColor = color
    }

    func setValue(_ value: Int) {
        valueLabel.text = value.compactFormatted
    }

    func setValue(_ text: String) {
        valueLabel.text = text
    }
}

@available(iOS 17.0, *)
private func makeStatStack(reviewedText: String, deleted: Int, kept: Int, stored: Int) -> UIView {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.spacing = 8
    stack.translatesAutoresizingMaskIntoConstraints = false

    let reviewedView = MonthStatItemView()
    reviewedView.configure(title: NSLocalizedString("filterCards.reviewed", comment: ""), color: .systemGray)
    reviewedView.setValue(reviewedText)

    let deletedView = MonthStatItemView()
    deletedView.configure(title: NSLocalizedString("filterCards.delete", comment: ""), color: .systemRed)
    deletedView.setValue(deleted)

    let keptView = MonthStatItemView()
    keptView.configure(title: NSLocalizedString("filterCards.keep", comment: ""), color: .systemGreen)
    keptView.setValue(kept)

    let storedView = MonthStatItemView()
    storedView.configure(title: NSLocalizedString("filterCards.store", comment: ""), color: .systemYellow)
    storedView.setValue(stored)

    [reviewedView, deletedView, keptView, storedView].forEach { stack.addArrangedSubview($0) }

    let container = UIView()
    container.backgroundColor = .mainBackground
    container.addSubview(stack)
    NSLayoutConstraint.activate([
        stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
        stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        stack.heightAnchor.constraint(equalToConstant: 50)
    ])
    return container
}

@available(iOS 17.0, *)
#Preview("Small numbers") {
    makeStatStack(reviewedText: "12/40", deleted: 5, kept: 7, stored: 0)
}

@available(iOS 17.0, *)
#Preview("Large numbers (K)") {
    makeStatStack(reviewedText: "3.2K/5K", deleted: 1200, kept: 1500, stored: 500)
}

@available(iOS 17.0, *)
#Preview("Very large numbers") {
    makeStatStack(reviewedText: "12K/20K", deleted: 8000, kept: 3000, stored: 1000)
}
