// tomocy

import Metal

enum Shader {}

extension Shader {
    struct Shader {
        var commandQueue: MTLCommandQueue
        var add: Add
    }
}

extension Shader.Shader {
    init(device: some MTLDevice) throws {
        commandQueue = device.makeCommandQueue()!
        add = try .init(device: device)
    }
}

extension Shader {
    struct Add {
        var pipelineState: MTLComputePipelineState
    }
}

extension Shader.Add {
    init(device: some MTLDevice) throws {
        let lib = device.makeDefaultLibrary()!

        pipelineState = try device.makeComputePipelineState(
            function: lib.makeFunction(name: "add")!
        )
    }
}

extension Shader.Add {
    func encode(to buffer: some MTLCommandBuffer, a: [Float], b: [Float]) -> some MTLBuffer {
        let encoder = buffer.makeComputeCommandEncoder()!
        defer { encoder.endEncoding() }

        encoder.setComputePipelineState(pipelineState)

        assert(a.count == b.count)
        let count = a.count

        let result = encoder.device.makeBuffer(
            length: MemoryLayout<Float>.stride * count,
            options: .storageModeShared
        )!

        encoder.setBuffer(result, offset: 0, index: 0)

        a.withUnsafeBytes { bytes in
            let buffer = encoder.device.makeBuffer(
                bytes: bytes.baseAddress!,
                length: bytes.count,
                options: .storageModeShared
            )

            encoder.setBuffer(buffer, offset: 0, index: 1)
        }

        b.withUnsafeBytes { bytes in
            let buffer = encoder.device.makeBuffer(
                bytes: bytes.baseAddress!,
                length: bytes.count,
                options: .storageModeShared
            )

            encoder.setBuffer(buffer, offset: 0, index: 2)
        }

        encoder.dispatchThreadgroups(
            .init(width: count, height: 1, depth: 1),
            threadsPerThreadgroup: .init(
                width: Swift.min(
                    count,
                    pipelineState.maxTotalThreadsPerThreadgroup
                ),
                height: 1, depth: 1
            )
        )

        return result
    }
}

extension MTLCommandBuffer {
    func commit(_ code: () -> Void) {
        code()
        commit()
    }
}
