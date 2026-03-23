//
//  GrayscaleConverter.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 2.03.2026.
//

import UIKit
import CoreImage

enum GrayscaleConverter {

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func apply(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image),
              let filter = CIFilter(name: "CIPhotoEffectMono") else { return nil }

        filter.setValue(ciImage, forKey: kCIInputImageKey)

        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: ciImage.extent) else { return nil }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
