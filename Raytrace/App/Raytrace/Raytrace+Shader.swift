// tomocy

import Metal

extension Raytrace {
    struct Shader {
        var commandQueue: MTLCommandQueue

        var accelerator: Accelerator

        var raytrace: Raytrace
        var echo: Echo
    }
}

extension Raytrace.Shader {
    init(device: some MTLDevice, resolution: CGSize, format: MTLPixelFormat) throws {
        commandQueue = device.makeCommandQueue()!

        accelerator = .init()

        raytrace = try .init(device: device, resolution: resolution)
        echo = try .init(device: device, format: format)
    }
}
