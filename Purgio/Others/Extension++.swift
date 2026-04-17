//
//  Extension++.swift
//  CineVault
//
//  Created by Zeynep Müslim on 10.07.2025.
//

import Foundation
import UIKit.UIView

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
