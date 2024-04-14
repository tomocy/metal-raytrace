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
        let onDevice = Raytrace.Metal.bufferBuildable(self).build(
            with: encoder.device,
            label: label,
            options: .storageModeShared
        )!

        let onHeap = onDevice.copy(with: encoder, to: heap)

        encoder.copy(
            from: onDevice, sourceOffset: 0,
            to: onHeap, destinationOffset: 0,
            size: onHeap.length
        )

        return onHeap
    }
}
