// tomocy

import Metal

struct Prelight {
    var pipelineStates: PipelineStates
    var args: Args

    var source: any MTLTexture
    var target: any MTLTexture
}

extension Prelight {
    init(device: some MTLDevice, source: some MTLTexture) throws {
        let lib = device.makeDefaultLibrary()!
        let fn = lib.makeFunction(name: "Prelight::compute")!

        pipelineStates = .init(
            compute: try PipelineStates.make(with: device, for: fn)
        )
        args = .init(
            encoder: Args.make(for: fn)
        )

        do {
            self.source = source
            source.label!.append(",Prelight/Source")
        }

        target = Texture.makeCube(
            with: device,
            label: "Prelight/Target",
            format: .bgra8Unorm,
            size: source.width,
            usage: [.shaderRead, .shaderWrite],
            storageMode: .managed,
            mipmapped: false
        )!
    }
}

extension Prelight {
    func encode(to buffer: some MTLCommandBuffer) {
        let encoder = buffer.makeComputeCommandEncoder()!
        defer { encoder.endEncoding() }

        encoder.setComputePipelineState(pipelineStates.compute)

        do {
            let buffer = args.build(source, target, with: encoder)!
            encoder.setBuffer(buffer, offset: 0, index: 0)
        }

        do {
            let (width, height) = (target.width, target.width * 6 /* face count in a cube */)

            let threadsSizePerGroup = MTLSize.init(width: 8, height: 8, depth: 1)
            let threadsGroupSize = MTLSize.init(
                width: width.align(by: threadsSizePerGroup.width) / threadsSizePerGroup.width,
                height: height.align(by: threadsSizePerGroup.height) / threadsSizePerGroup.height,
                depth: threadsSizePerGroup.depth
            )

            encoder.dispatchThreadgroups(
                threadsGroupSize,
                threadsPerThreadgroup: threadsSizePerGroup
            )
        }
    }
}

extension Prelight {
    struct PipelineStates {
        var compute: any MTLComputePipelineState
    }
}

extension Prelight.PipelineStates {
    static func make(with device: some MTLDevice, for function: some MTLFunction) throws -> any MTLComputePipelineState {
        return try device.makeComputePipelineState(
            function: function
        )
    }
}

extension Prelight {
    struct Args {
        var encoder: any MTLArgumentEncoder
    }
}

extension Prelight.Args {
    static func make(for function: some MTLFunction) -> any MTLArgumentEncoder {
        return function.makeArgumentEncoder(bufferIndex: 0)
    }
}

extension Prelight.Args {
    func build(
        _ source: some MTLTexture,
        _ target: some MTLTexture,
        with encoder: some MTLComputeCommandEncoder
    ) -> (any MTLBuffer)? {
        guard let buffer = encoder.device.makeBuffer(
            length: self.encoder.encodedLength
        ) else { return nil }

        buffer.label = "Args"

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