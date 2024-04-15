// tomocy

import Foundation
import CoreGraphics
import CoreImage
import MetalKit

struct App {
    private(set) var args: Args

    private var commandQueue: any MTLCommandQueue
    private var prelight: Prelight
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
                diffuse: try .init(device: device, source: source),
                specular: try .init(device: device, source: source),
                env: try .init(device: device)
            )
        }
    }
}

extension App {
    func preLight() async throws {
        do {
            let command = commandQueue.makeCommandBuffer()!
            command.label = "Diffuse"

            try await process(label: "Prelight: Diffuse") {
                try await command.complete {
                    try command.commit {
                        prelight.diffuse.encode(to: command)
                    }
                }
            }
        }

        do {
            let command = commandQueue.makeCommandBuffer()!
            command.label = "Specular"

            try await process(label: "Prelight: Specular") {
                try await command.complete {
                    try command.commit {
                        prelight.specular.encode(to: command)
                    }
                }
            }
        }

        do {
            let command = commandQueue.makeCommandBuffer()!
            command.label = "Env"

            try await process(label: "Prelight: Env") {
                try await command.complete {
                    try command.commit {
                        prelight.env.encode(to: command)
                    }
                }
            }
        }
    }
}

extension App {
    func save() async throws {
        async let diffuse: () = save(prelight.diffuse.target, label: "Prelight_Diffuse")
        async let specular: () = save(prelight.specular.target, label: "Prelight_Specular")
        async let env: () = save(prelight.env.target, label: "Prelight_Env_GGX")

        _ = try await (diffuse, specular, env)
    }

    private func save(_ texture: some MTLTexture, label: String) async throws {
        let image: CGImage = texture.into(
            in: CGColorSpace.init(name: CGColorSpace.linearSRGB)!,
            mipmapLevel: 0
        )!

        let url = ({
            let name = (args.sourceURL.lastPathComponent as NSString).deletingPathExtension
            return args.sourceURL.deletingLastPathComponent().appending(path: "\(name)_\(label).png")
        }) ()

        try await process(label: "Save: \(url.lastPathComponent)") {
            try image.save(at: url, as: .png)
        }
    }
}

extension App {
    private func process(label: String = "Processing", _ code: () async throws -> Void) async throws {
        print("> \(label)")
        defer { print("[Done] \(label)") }

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
