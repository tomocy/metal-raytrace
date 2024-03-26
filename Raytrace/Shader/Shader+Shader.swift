// tomocy

import Metal

enum Shader {}

extension Shader {
    struct Shader {
        var commandQueue: MTLCommandQueue
        var raytrace: Raytrace
        var copy: Echo
    }
}

extension Shader.Shader {
    init(device: some MTLDevice, size: CGSize, format: MTLPixelFormat) throws {
        commandQueue = device.makeCommandQueue()!
        raytrace = try .init(device: device, size: size, format: format)
        copy = try .init(device: device, format: format)
    }
}

extension MTLCommandBuffer {
    func commit(_ code: () -> Void) {
        code()
        commit()
    }
}
