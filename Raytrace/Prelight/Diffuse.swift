// tomocy

import Metal

extension Prelight {
    struct Diffuse {
        private var kernel: Kernel
    }
}

extension Prelight.Diffuse {
    init(device: some MTLDevice, source: some MTLTexture) throws {
        let lib = device.makeDefaultLibrary()!
        let fn = lib.makeFunction(name: "Prelight::Diffuse::compute")!

        kernel = try .init(
            device: device,
            label: "Diffuse",
            function: fn,
            source: source
        )
    }
}

extension Prelight.Diffuse {
    var target: some MTLTexture { kernel.target }
}

extension Prelight.Diffuse {
    func encode(to buffer: some MTLCommandBuffer) {
        kernel.encode(to: buffer)
    }
}
