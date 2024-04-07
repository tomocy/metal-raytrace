// tomocy

import Foundation
import CoreGraphics
import AppKit

extension CGColorSpace {
    static func sRGB() -> CGColorSpace? { .init(name: CGColorSpace.sRGB)  }
}

extension CGImage {
    func save(at url: URL, as type: NSBitmapImageRep.FileType) throws {
        let bitmap = NSBitmapImageRep.init(cgImage: self)
        bitmap.size = .init(width: width, height: height)

        let data = bitmap.representation(
            using: type,
            properties: [:]
        )!

        try data.write(to: url, options: .atomic)
    }
}
