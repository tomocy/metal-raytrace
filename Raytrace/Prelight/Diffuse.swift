// tomocy

import Metal

extension Prelight {
    struct Diffuse {
        private var kernel: Kernel

        private var source: any MTLTexture
        private(set) var target: any MTLTexture
    }
}

extension Prelight.Diffuse {
    init(device: some MTLDevice, source: some MTLTexture) throws {
        let lib = device.makeDefaultLibrary()!
        let fn = lib.makeFunction(name: "Prelight::Diffuse::compute")!

        kernel = try .init(device: device, label: "Diffuse", function: fn)

        do {
            self.source = source
            source.label!.append(",Prelight/Diffuse/Source")
        }

        target = Texture.make2D(
            with: device,
            label: "Prelight/Diffuse/Target",
            format: .bgra8Unorm,
            size: .init(source.width, source.height * 6 /* face count in a cube */),
            usage: [.shaderRead, .shaderWrite],
            storageMode: .managed,
            mipmapped: false
        )!
    }
}

extension Prelight.Diffuse {
    func encode(to buffer: some MTLCommandBuffer) {
        kernel.encode(to: buffer, source: source, target: target)
    }
}
