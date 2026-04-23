//
//  FakeAlbumCell.swift
//  Purgio
//
//  Created by ZeynepMüslim on 22.03.2026.
//

import UIKit

final class FakeAlbumCell: UICollectionViewCell {

    static let reuseIdentifier = "FakeAlbumCell"

    private let thumbnailView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    let photoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isHidden = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let gradientView: GradientView = {
        let view = GradientView()
        view.colors = [.black.withAlphaComponent(0.0), .black.withAlphaComponent(0.5)]
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .left
        label.textColor = .white
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let badgeImageView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        imageView.image = UIImage(systemName: "heart.fill", withConfiguration: config)
        imageView.tintColor = .white
        imageView.isHidden = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(thumbnailView)
        thumbnailView.addSubview(iconImageView)
        thumbnailView.addSubview(photoImageView)
        thumbnailView.addSubview(gradientView)
        thumbnailView.addSubview(titleLabel)
        thumbnailView.addSubview(badgeImageView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            thumbnailView.heightAnchor.constraint(equalTo: thumbnailView.widthAnchor),

            iconImageView.centerXAnchor.constraint(equalTo: thumbnailView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: thumbnailView.centerYAnchor),

            photoImageView.topAnchor.constraint(equalTo: thumbnailView.topAnchor),
            photoImageView.leadingAnchor.constraint(equalTo: thumbnailView.leadingAnchor),
            photoImageView.trailingAnchor.constraint(equalTo: thumbnailView.trailingAnchor),
            photoImageView.bottomAnchor.constraint(equalTo: thumbnailView.bottomAnchor),

            gradientView.leadingAnchor.constraint(equalTo: thumbnailView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: thumbnailView.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: thumbnailView.bottomAnchor),
            gradientView.heightAnchor.constraint(equalTo: thumbnailView.heightAnchor, multiplier: 0.8),

            titleLabel.leadingAnchor.constraint(equalTo: thumbnailView.leadingAnchor, constant: 16),
            titleLabel.bottomAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: -16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: thumbnailView.trailingAnchor, constant: -16),

            badgeImageView.topAnchor.constraint(equalTo: thumbnailView.topAnchor, constant: 8),
            badgeImageView.trailingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: -8)
        ])
    }


    func configure(title: String, sfSymbol: String, tint: UIColor, showBadge: Bool = false) {
        titleLabel.text = title
        thumbnailView.backgroundColor = tint
        
        let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        iconImageView.image = UIImage(systemName: sfSymbol, withConfiguration: config)
        iconImageView.isHidden = false
        titleLabel.isHidden = false
        gradientView.isHidden = false
        badgeImageView.isHidden = !showBadge
    }

    func configureDefault() {
        titleLabel.isHidden = true
        iconImageView.isHidden = true
        gradientView.isHidden = true
        badgeImageView.isHidden = true
        thumbnailView.backgroundColor = .systemGray5
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        photoImageView.image = nil
        photoImageView.isHidden = true
        iconImageView.isHidden = false
        badgeImageView.isHidden = true
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct FakeAlbumCellPreview: UIViewRepresentable {
        let title: String?
        let sfSymbol: String?
        let tint: UIColor?
        let showBadge: Bool

        func makeUIView(context: Context) -> FakeAlbumCell {
            let cell = FakeAlbumCell(frame: .zero)
            if let title, let sfSymbol, let tint {
                cell.configure(title: title, sfSymbol: sfSymbol, tint: tint, showBadge: showBadge)
            } else {
                cell.configureDefault()
            }
            return cell
        }

        func updateUIView(_ uiView: FakeAlbumCell, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Album Cell - Recents") {
        FakeAlbumCellPreview(title: "Recents", sfSymbol: "clock.fill", tint: .systemBlue, showBadge: false)
            .frame(width: 160, height: 160)
            .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Album Cell - Favorites") {
        FakeAlbumCellPreview(title: "Favorites", sfSymbol: "heart.fill", tint: .systemPink, showBadge: true)
            .frame(width: 160, height: 160)
            .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Album Cell - Default") {
        FakeAlbumCellPreview(title: nil, sfSymbol: nil, tint: nil, showBadge: false)
            .frame(width: 160, height: 160)
            .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Album Cell - Will Be Stored") {
        FakeAlbumCellPreview(
            title: "Will Be Stored", sfSymbol: "archivebox.fill", tint: .systemYellow, showBadge: false
        )
        .frame(width: 160, height: 160)
        .padding()
    }
#endif
