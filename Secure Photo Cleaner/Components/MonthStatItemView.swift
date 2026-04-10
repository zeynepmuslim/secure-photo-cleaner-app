//
//  MonthStatItemView.swift
//  Secure Photo Cleaner
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
        valueLabel.text = "\(value)"
    }

    func setValue(_ text: String) {
        valueLabel.text = text
    }
}

@available(iOS 17.0, *)
#Preview {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.spacing = 8
    stack.translatesAutoresizingMaskIntoConstraints = false

    let reviewed = MonthStatItemView()
    reviewed.configure(title: NSLocalizedString("filterCards.reviewed", comment: ""), color: .systemGray)
    reviewed.setValue("12/40")

    let deleted = MonthStatItemView()
    deleted.configure(title: NSLocalizedString("filterCards.delete", comment: ""), color: .systemRed)
    deleted.setValue(5)

    let kept = MonthStatItemView()
    kept.configure(title: NSLocalizedString("filterCards.keep", comment: ""), color: .systemGreen)
    kept.setValue(7)

    let stored = MonthStatItemView()
    stored.configure(title: NSLocalizedString("filterCards.store", comment: ""), color: .systemYellow)
    stored.setValue(0)

    [reviewed, deleted, kept, stored].forEach { stack.addArrangedSubview($0) }

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
