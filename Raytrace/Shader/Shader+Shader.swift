// tomocy

import Metal

enum Shader {}

extension Shader {
    struct Shader {
        var commandQueue: MTLCommandQueue

        var accelerator: Accelerator

        var raytrace: Raytrace
        var echo: Echo

        var debug: Debug
    }
}

extension Shader.Shader {
    init(device: some MTLDevice, resolution: CGSize, format: MTLPixelFormat) throws {
        commandQueue = device.makeCommandQueue()!

        accelerator = .init()

        raytrace = try .init(device: device, resolution: resolution)
        echo = try .init(device: device, format: format)

        debug = .init(device: device)
    }
}

extension MTLCommandBuffer {
    func commit(_ code: () -> Void) {
        code()
        commit()
    }
}
