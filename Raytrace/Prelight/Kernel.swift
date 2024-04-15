// tomocy

import Metal

extension Prelight {
    struct Kernel {
        var label: String

        private var pipelineStates: PipelineStates
        private var args: Args

        private var source: any MTLTexture
        private(set) var target: any MTLTexture
    }
}

extension Prelight.Kernel {
    init(device: some MTLDevice, label: String, function: some MTLFunction, source: some MTLTexture) throws {
        self.label = label

        pipelineStates = .init(
            compute: try PipelineStates.make(with: device, for: function)
        )
        args = .init(
            encoder: Args.make(for: function)
        )

        do {
            self.source = source
            source.label!.append(",\(label)/Source")
        }

        target = Texture.make2D(
            with: device,
            label: "\(label)/Target",
            format: .bgra8Unorm,
            size: .init(source.width, source.height * 6 /* face count in a cube */),
            usage: [.shaderRead, .shaderWrite],
            storageMode: .private,
            mipmapped: false
        )!
    }
}

extension Prelight.Kernel {
    func encode(to buffer: some MTLCommandBuffer) {
        let encoder = buffer.makeComputeCommandEncoder()!
        defer { encoder.endEncoding() }

        encoder.label = label

        encoder.setComputePipelineState(pipelineStates.compute)

        do {
            let buffer = args.build(source, target, with: encoder, label: "\(label)/Args")!
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

extension Prelight.Kernel {
    struct PipelineStates {
        var compute: any MTLComputePipelineState
    }
}

extension Prelight.Kernel.PipelineStates {
    static func make(with device: some MTLDevice, for function: some MTLFunction) throws -> any MTLComputePipelineState {
        return try device.makeComputePipelineState(
            function: function
        )
    }
}

extension Prelight.Kernel {
    struct Args {
        var encoder: any MTLArgumentEncoder
    }
}

extension Prelight.Kernel.Args {
    static func make(for function: some MTLFunction) -> any MTLArgumentEncoder {
        return function.makeArgumentEncoder(bufferIndex: 0)
    }
}

extension Prelight.Kernel.Args {
    func build(
        _ source: some MTLTexture,
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
