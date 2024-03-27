// tomocy

import Metal

enum Shader {}

extension Shader {
    struct Shader {
        var commandQueue: MTLCommandQueue

        var accelerator: Accelerator
        var raytrace: Raytrace
        var echo: Echo
    }
}

extension Shader.Shader {
    init(device: some MTLDevice, size: CGSize, format: MTLPixelFormat) throws {
        commandQueue = device.makeCommandQueue()!

        accelerator = .init()
        raytrace = try .init(device: device, size: size, format: format)
        echo = try .init(device: device, format: format)
    }
}

extension MTLCommandBuffer {
    func commit(_ code: () -> Void) {
        code()
        commit()
    }
}
