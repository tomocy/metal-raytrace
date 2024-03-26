// tomocy

import Cocoa


let app = NSApplication.shared

app.setActivationPolicy(.regular)

let title = "Raytrace"
let (delegate, menu) = (
    Engine.App.init(
        window: Engine.Window.init(
            title: title,
            size: .init(width: 800, height: 600)
        )
    ),
    Engine.App.Menu.init(title: title)
)

app.delegate = delegate
app.menu = menu

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
