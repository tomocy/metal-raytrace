// tomocy

import Cocoa

enum Engine {}

extension Engine {
    class App: NSObject {
        init(window: NSWindow) {
            self.window = window
        }

        private var window: NSWindow
    }
}

extension Engine.App: NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        window.makeKeyAndOrderFront(notification)
        window.center()

        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

extension Engine.App {
    class Menu: NSMenu {
        required init(coder: NSCoder) { super.init(coder: coder) }

        override init(title: String) {
            super.init(title: title)

            do {
                let item = NSMenuItem.init()
                item.submenu = .init()

                item.submenu!.items.append(
                    .init(
                        title: "Quit",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q"
                    )
                )

                addItem(item)
            }
        }
    }
}
