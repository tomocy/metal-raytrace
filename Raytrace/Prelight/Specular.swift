// tomocy

import Metal

extension Prelight {
    struct Specular {
        private var kernel: Kernel
    }
}

extension Prelight.Specular {
    init(device: some MTLDevice, source: some MTLTexture) throws {
        let lib = device.makeDefaultLibrary()!
        let fn = lib.makeFunction(name: "Prelight::Specular::compute")!

        kernel = try .init(
            device: device,
            label: "Specular",
            function: fn,
            source: source
        )
    }
}

extension Prelight.Specular {
    var target: some MTLTexture { kernel.target }
}

extension Prelight.Specular {
    func encode(to buffer: some MTLCommandBuffer) {
        kernel.encode(to: buffer)
    }
}
