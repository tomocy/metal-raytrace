// tomocy

import CoreGraphics

extension CGColor {
    var red: CGFloat { components?[0] ?? 0 }
    var green: CGFloat { components?[1] ?? 0 }
    var blue: CGFloat { components?[2] ?? 0 }
    var alpha: CGFloat { components?[3] ?? 0 }
}
