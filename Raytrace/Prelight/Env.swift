// tomocy

import Metal

extension Prelight {
    struct Env {
        private var pipelineStates: Kernel.PipelineStates
        private var args: Args

        private(set) var target: any MTLTexture
    }
}

extension Prelight.Env {
    init(device: some MTLDevice) throws {
        let lib = device.makeDefaultLibrary()!
        let fn = lib.makeFunction(name: "Prelight::Env::compute")!

        pipelineStates = .init(
            compute: try Prelight.Kernel.PipelineStates.make(with: device, for: fn)
        )
        args = .init(
            encoder: Args.make(for: fn)
        )

        target = Texture.make2D(
            with: device,
            label: "Env/Target",
            format: .bgra8Unorm,
            size: .init(128, 128),
            usage: [.shaderRead, .shaderWrite],
            storageMode: .private,
            mipmapped: false
        )!
    }
}

extension Prelight.Env {
    func encode(to buffer: some MTLCommandBuffer) {
        let encoder = buffer.makeComputeCommandEncoder()!
        defer { encoder.endEncoding() }

        encoder.label = "Env"

        encoder.setComputePipelineState(pipelineStates.compute)

        do {
            let buffer = args.build(target, with: encoder, label: "Env/Args")!
            encoder.setBuffer(buffer, offset: 0, index: 0)
        }

        do {
            let threadsSizePerGroup = encoder.defaultThreadsSizePerGroup
            let threadsGroupSize = encoder.threadsGroupSize(
                for: .init(target.width, target.height),
                as: threadsSizePerGroup
            )

            encoder.dispatchThreadgroups(
                threadsGroupSize,
                threadsPerThreadgroup: threadsSizePerGroup
            )
        }
    }
}

extension Prelight.Env {
    struct Args {
        var encoder: any MTLArgumentEncoder
    }
}

extension Prelight.Env.Args {
    static func make(for function: some MTLFunction) -> any MTLArgumentEncoder {
        return function.makeArgumentEncoder(bufferIndex: 0)
    }
}

extension Prelight.Env.Args {
    func build(
        _ target: some MTLTexture,
        with encoder: some MTLComputeCommandEncoder,
        label: String
    ) -> (any MTLBuffer)? {
        guard let buffer = encoder.device.makeBuffer(
            length: self.encoder.encodedLength
        ) else { return nil }

        buffer.label = label

        self.encoder.setArgumentBuffer(buffer, offset: 0)

        do {
            encoder.useResource(target, usage: .write)
            self.encoder.setTexture(target, index: 0)
        }

        return buffer
    }
}
