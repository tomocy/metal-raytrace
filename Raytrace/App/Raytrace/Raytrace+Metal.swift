// tomocy

import Metal

extension Raytrace {
    enum Metal {}
}

extension Raytrace.Metal {
    enum Buffer {}
}

extension Raytrace.Metal.Buffer {
    typealias Buildable = _ShaderMetalBufferBuildable
}

protocol _ShaderMetalBufferBuildable {
    func build(with device: some MTLDevice, label: String?, options: MTLResourceOptions) -> (any MTLBuffer)?
}

extension Raytrace.Metal.Buffer.Buildable {
    func build(with device: some MTLDevice, label: String? = nil, options: MTLResourceOptions = []) -> (any MTLBuffer)? {
        return build(with: device, label: label, options: options)
    }

    func build(with encoder: some MTLBlitCommandEncoder, on heap: some MTLHeap, label: String? = nil) -> (any MTLBuffer)? {
        let onDevice = build(with: encoder.device, label: label, options: .storageModeShared)
        return onDevice?.copy(with: encoder, to: heap)
    }
}

extension Raytrace.Metal.Buffer {
    static func buildable<T>(_ value: T) -> some Buildable {
        return DefaultBuildable.init(value: value)
    }

    static func buildable(_ value: some Buildable) -> some Buildable {
        return value
    }
}

extension Raytrace.Metal.Buffer {
    struct DefaultBuildable<T> {
        var value: T
    }
}

extension Raytrace.Metal.Buffer.DefaultBuildable: Raytrace.Metal.Buffer.Buildable {
    func build(with device: some MTLDevice, label: String?, options: MTLResourceOptions) -> (any MTLBuffer)? {
        guard let buffer = withUnsafeBytes(of: value, { bytes in
            device.makeBuffer(
                bytes: bytes.baseAddress!,
                length: bytes.count,
                options: options
            )
        }) else { return nil }

        buffer.label = label

        return buffer
    }
}

extension Array: Raytrace.Metal.Buffer.Buildable {
    func build(with device: some MTLDevice, label: String?, options: MTLResourceOptions) -> (any MTLBuffer)? {
        guard let buffer = withUnsafeBytes({ bytes in
            device.makeBuffer(
                bytes: bytes.baseAddress!,
                length: bytes.count,
                options: options
            )
        }) else { return nil }

        buffer.label = label

        return buffer
    }
}

extension MTLBuffer {
    func use(with encoder: some MTLComputeCommandEncoder, usage: MTLResourceUsage) -> UInt64 {
        encoder.useResource(self, usage: usage)
        return gpuAddress
    }
}

extension MTLBuffer {
    func copy(
        with encoder: some MTLBlitCommandEncoder,
        to heap: some MTLHeap,
        label: String? = nil
    ) -> any MTLBuffer {
        let onHeap = heap.makeBuffer(
            length: length,
            options: .storageModePrivate
        )!

        onHeap.label = label ?? self.label

        encoder.copy(from: self, to: onHeap)

        return onHeap
    }
}

extension MTLTexture {
    var descriptor: MTLTextureDescriptor {
        let desc = MTLTextureDescriptor.init()

        desc.textureType = textureType
        desc.pixelFormat = pixelFormat
        desc.width = width
        desc.height = height
        desc.depth = depth
        desc.mipmapLevelCount = mipmapLevelCount
        desc.arrayLength = arrayLength
        desc.sampleCount = sampleCount
        desc.storageMode = storageMode

        return desc
    }
}

extension MTLTexture {
    func use(with encoder: some MTLComputeCommandEncoder, usage: MTLResourceUsage) -> MTLResourceID {
        encoder.useResource(self, usage: usage)
        return gpuResourceID
    }
}

extension MTLTexture {
    func measureHeapSize(with device: some MTLDevice) -> Int {
        return device.heapTextureSizeAndAlign(descriptor: descriptor).aligned
    }

    func copy(
        with encoder: some MTLBlitCommandEncoder,
        to heap: some MTLHeap,
        label: String? = nil
    ) -> any MTLTexture {
        let desc = descriptor
        desc.storageMode = .private

        let onHeap = heap.makeTexture(descriptor: desc)!
        onHeap.label = label ?? self.label

        encoder.copy(from: self, to: onHeap)

        return onHeap
    }
}

extension MTLCommandBuffer {
    func commit(_ code: () -> Void) {
        code()
        commit()
    }
}

extension MTLBlitCommandEncoder {
    func copy(
        from source: some MTLBuffer, to destination: some MTLBuffer,
        size: Int? = nil
    ) {
        copy(
            from: source, sourceOffset: 0,
            to: destination, destinationOffset: 0,
            size: size ?? destination.length
        )
    }
}

extension Array {
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

extension MTLComputeCommandEncoder {
    var defaultThreadsSizePerGroup: MTLSize { .init(width: 8, height: 8, depth: 1) }

    func threadsGroupSize(for size: SIMD2<Int>, as threadsSize: MTLSize) -> MTLSize {
        .init(
            width: size.x.align(by: threadsSize.width) / threadsSize.width,
            height: size.y.align(by: threadsSize.height) / threadsSize.height,
            depth: threadsSize.depth
        )
    }
}

struct MTLComputeArgumentEncoder {
    var compute: any MTLComputeCommandEncoder
}

extension MTLSizeAndAlign {
    var aligned: Int {
        size.align(by: align)
    }
}

struct MTLOnHeap<T> {
    var value: T
    var heap: any MTLHeap
}
