// tomocy

import Metal

extension Raytrace {
    struct Frame {
        var id: UInt32
    }
}

extension Raytrace.Frame {
    func build(
        with encoder: some MTLBlitCommandEncoder,
        on heap: some MTLHeap,
        label: String
    ) -> some MTLBuffer {
        return Raytrace.Metal.Buffer.buildable(self).build(
            with: encoder,
            on: heap,
            label: label
        )!
    }
}
