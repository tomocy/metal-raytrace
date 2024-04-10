// tomocy

import Cocoa
import Metal

extension Engine {
    class Window: NSWindow {
        init(title: String, size: CGSize, view: NSView) {
            super.init(
                contentRect: .init(
                    origin: .init(x: 0, y: 0),
                    size: size
                ),
                styleMask: [.titled, .miniaturizable, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            self.title = title

            contentView = view
            makeFirstResponder(contentView)
        }
    }
}

extension Engine.Window {
    convenience init(title: String, size: CGSize) {
        self.init(
            title: title,
            size: size,
            view: Engine.View.init(
                device: MTLCreateSystemDefaultDevice()!,
                size: size
            )
        )
    }
}
