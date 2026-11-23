//
//  Extension++.swift
//  CineVault
//
//  Created by Zeynep Müslim on 10.07.2025.
//

import Foundation
import UIKit.UIView

extension Int {
    /// A count in at most 4 characters: "950", "1.5K", "12K". The thousands suffix and the
    /// decimal separator follow the app's language, so Turkish reads "1,5B", "12B".
    var compactFormatted: String {
        guard self >= 1_000 else { return "\(self)" }
        let suffix = CommonStrings.thousandsSuffix
        if self >= 10_000 { return "\(self / 1_000)\(suffix)" }
        let thousands = NSNumber(value: Double(self) / 1_000)
        let number = Self.compactThousandsFormatter.string(from: thousands) ?? "\(self / 1_000)"
        return number + suffix
    }

    /// One fraction digit at most, rounded down so a count is never overstated, in the
    /// app's language rather than the region's
    private static let compactThousandsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.roundingMode = .down
        return formatter
    }()
}

extension Int {
    /// This count as a rounded percent of `total`, the one figure every progress text shows.
    /// While some but not all of it is done it stays within 1…99, so "0%" never means started
    /// and "100%" never comes with items left.
    func roundedPercent(of total: Int) -> Int {
        guard total > 0, self > 0 else { return 0 }
        guard self < total else { return 100 }
        return Swift.min(99, Swift.max(1, Int((Double(self) * 100 / Double(total)).rounded())))
    }
}

extension Int64 {
    func formattedBytes(allowedUnits: ByteCountFormatter.Units = [.useKB, .useMB, .useGB]) -> String {
        let formatter = Self.byteFormatter
        formatter.allowedUnits = allowedUnits
        return formatter.string(fromByteCount: self)
    }

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
}

public extension UIView {
    /// Creates a spacer view with optional width and height constraints
    /// - Parameters:
    ///   - width: Optional constant width for the spacer
    ///   - height: Optional constant height for the spacer
    /// - Returns: A UIView configured as a spacer with the specified dimensions
    static func spacer(width: CGFloat? = nil, height: CGFloat? = nil) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        
        if let width = width {
            view.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        
        if let height = height {
            view.heightAnchor.constraint(equalToConstant: height).isActive = true
        }
        
        return view
    }
    
    /// Creates a flexible spacer view that expands to fill available space
    /// - Returns: A UIView configured as a flexible spacer
    static func flexibleSpacer() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

extension UIImage {
    /// The first of these SF Symbol names this iOS has; the last one when none resolves.
    /// For symbols newer than iOS 15: `availableSymbolName("photo.stack", "photo.on.rectangle.angled")`.
    static func availableSymbolName(_ candidates: String...) -> String {
        candidates.first { UIImage(systemName: $0) != nil } ?? candidates.last ?? ""
    }
}
