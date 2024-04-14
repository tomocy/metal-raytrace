// tomocy

import Metal

extension Raytrace {
    enum Metal {}
}

extension Raytrace.Metal {
    static func bufferBuildable<T>(_ value: T) -> some BufferBuildable {
        return DefaultBufferAllocatable.init(value: value)
    }

    static func bufferBuildable(_ value: some BufferBuildable) -> some BufferBuildable {
        return value
    }
}

extension Raytrace.Metal {
    typealias BufferBuildable = _ShaderMetalBufferBuildable
}

protocol _ShaderMetalBufferBuildable {
    func build(with device: some MTLDevice, label: String?, options: MTLResourceOptions) -> (any MTLBuffer)?
}

extension Raytrace.Metal.BufferBuildable {
    func build(with device: some MTLDevice, label: String? = nil, options: MTLResourceOptions = []) -> (any MTLBuffer)? {
        return build(with: device, label: label, options: options)
    }

    func build(with encoder: some MTLBlitCommandEncoder, on heap: some MTLHeap, label: String? = nil) -> (any MTLBuffer)? {
        let onDevice = build(with: encoder.device, label: label, options: .storageModeShared)
        return onDevice?.copy(with: encoder, to: heap)
    }
}

extension Raytrace.Metal {
    struct DefaultBufferAllocatable<T> {
        var value: T
    }
}

extension Raytrace.Metal.DefaultBufferAllocatable: Raytrace.Metal.BufferBuildable {
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

extension Array: Raytrace.Metal.BufferBuildable {
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
        return Raytrace.Metal.bufferBuildable(self).build(
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
