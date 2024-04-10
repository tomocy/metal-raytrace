// tomocy

import Metal

extension Raytrace {
    struct Frame {
        var id: UInt32
    }
}

extension Raytrace.Frame {
    func encode(
        with encoder: MTLComputeArgumentEncoder,
        at index: Int,
        label: String? = nil,
        usage: MTLResourceUsage
    ) {
        let buffer: some MTLBuffer = ({
            let encoder = encoder.make(for: index)!

            let buffer: some MTLBuffer = encoder.make(label: label)!
            encoder.compute.useResource(buffer, usage: .read)

            encode(with: encoder, to: buffer, usage: .read)

            return buffer
        }) ()

        encoder.argument.setBuffer(buffer, offset: 0, index: index)
    }

    func encode(with encoder: MTLComputeArgumentEncoder, to buffer: some MTLBuffer, usage: MTLResourceUsage) {
        encoder.argument.setArgumentBuffer(buffer, offset: 0)

        do {
            let buffer = encoder.argument.constantData(at: 0)
            Raytrace.IO.writable(id).write(to: buffer)
        }
    }
}
