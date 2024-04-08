// tomocy

import Metal

extension Prelight {
    struct Diffuse {
        private var pipelineStates: PipelineStates
        private var args: Args

        private var source: any MTLTexture
        private(set) var target: any MTLTexture
    }
}

extension Prelight.Diffuse {
    init(device: some MTLDevice, source: some MTLTexture) throws {
        let lib = device.makeDefaultLibrary()!
        let fn = lib.makeFunction(name: "Prelight::Diffuse::compute")!

        pipelineStates = .init(
            compute: try PipelineStates.make(with: device, for: fn)
        )
        args = .init(
            encoder: Args.make(for: fn)
        )

        do {
            self.source = source
            source.label!.append(",Prelight/Diffuse/Source")
        }

        target = Texture.make2D(
            with: device,
            label: "Prelight/Diffuse/Target",
            format: .bgra8Unorm,
            size: .init(
                width: source.width,
                height: source.height * 6 /* face count in a cube */
            ),
            usage: [.shaderRead, .shaderWrite],
            storageMode: .managed,
            mipmapped: false
        )!
    }
}

extension Prelight.Diffuse {
    func encode(to buffer: some MTLCommandBuffer) {
        let encoder = buffer.makeComputeCommandEncoder()!
        defer { encoder.endEncoding() }

        encoder.setComputePipelineState(pipelineStates.compute)

        do {
            let buffer = args.build(source, target, with: encoder)!
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

extension Prelight.Diffuse {
    struct PipelineStates {
        var compute: any MTLComputePipelineState
    }
}

extension Prelight.Diffuse.PipelineStates {
    static func make(with device: some MTLDevice, for function: some MTLFunction) throws -> any MTLComputePipelineState {
        return try device.makeComputePipelineState(
            function: function
        )
    }
}

extension Prelight.Diffuse {
    struct Args {
        var encoder: any MTLArgumentEncoder
    }
}

extension Prelight.Diffuse.Args {
    static func make(for function: some MTLFunction) -> any MTLArgumentEncoder {
        return function.makeArgumentEncoder(bufferIndex: 0)
    }
}

extension Prelight.Diffuse.Args {
    func build(
        _ source: some MTLTexture,
        _ target: some MTLTexture,
        with encoder: some MTLComputeCommandEncoder
    ) -> (any MTLBuffer)? {
        guard let buffer = encoder.device.makeBuffer(
            length: self.encoder.encodedLength
        ) else { return nil }

        buffer.label = "Prelight/Diffuse/Args"

        self.encoder.setArgumentBuffer(buffer, offset: 0)

        do {
            encoder.useResource(source, usage: .read)
            self.encoder.setTexture(source, index: 0)
        }
        do {
            encoder.useResource(target, usage: .write)
            self.encoder.setTexture(target, index: 1)
        }

        return buffer
    }
}
