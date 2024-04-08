// tomocy

import Foundation
import CoreGraphics
import CoreImage
import MetalKit

struct App {
    var args: Args

    var commandQueue: any MTLCommandQueue
    var prelight: Prelight
}

extension App {
    init(args: Args, device: some MTLDevice) throws {
        self.args = args

        commandQueue = device.makeCommandQueue()!

        do {
            let source = try MTKTextureLoader.init(device: device).newTexture(
                URL: args.sourceURL,
                options: [
                    .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                    .textureStorageMode: MTLStorageMode.private.rawValue,
                    .cubeLayout: MTKTextureLoader.CubeLayout.vertical.rawValue,
                    .generateMipmaps: false,
                ]
            )

            prelight = .init(
                diffuse: try Prelight.Diffuse.init(device: device, source: source)
            )
        }
    }
}

extension App {
    func run() async throws {
        try await preLight()
        try await save()
    }

    private func preLight() async throws {
        let command = commandQueue.makeCommandBuffer()!

        try await process(label: "Prelighting") {
            try await command.complete {
                try command.commit {
                    prelight.diffuse.encode(to: command)
                    // cubeTo2D.encode(to: command)
                }
            }
        }
    }

    private func save() async throws {
        let image: CGImage = prelight.diffuse.targets.d2.into(
            in: CGColorSpace.init(name: CGColorSpace.linearSRGB)!,
            mipmapLevel: 0
        )!

        let url = ({
            let name = (args.sourceURL.lastPathComponent as NSString).deletingPathExtension
            return args.sourceURL.deletingLastPathComponent().appending(path: "\(name)_Prelighted.png")
        }) ()

        try await process(label: "Saving") {
            try image.save(at: url, as: .png)
        }
    }
}

extension App {
    private func process(label: String, _ code: () async throws -> Void) async throws {
        print("\(label)...", terminator: "")
        defer { print("Done") }

        try await code()
    }
}

extension App {
    struct Args {
        var sourceURL: URL
        var capturesFrame: Bool = false
    }
}

extension App.Args {
    static func parse(_ arguments: [String]) -> (Self?, String?) {
        if arguments.count < 2 {
            return (nil, help)
        }

        let sourceURL = URL.init(fileURLWithPath: arguments[1])
        guard FileManager.default.fileExists(atPath: sourceURL.path()) else {
            return (nil, reportError(message: "<source>: the file wad not found: '\(sourceURL.path())'"))
        }

        var args = Self.init(sourceURL: sourceURL)

        let options = arguments.suffix(from: 2)
        for option in options {
            if option == "--captures-frame" {
                args.capturesFrame = true
                continue
            }

            return (nil, reportError(message: "unknown option: \(option)"))
        }

        return (args, nil)
    }

    static var help: String {
        """
# Prelight

## Usage
Prelight <source>

## Options
--captures-frame
  Captures the frame of the Metal workload
"""
    }

    static func reportError(message: String) -> String {
        """
Error:
\(message)
"""
    }
}

extension App.Args: CustomStringConvertible {
    var description: String {
    """
<source>: \(sourceURL.path())
"""
    }
}
