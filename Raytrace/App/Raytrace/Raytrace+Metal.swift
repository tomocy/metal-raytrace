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

extension MTLCommandBuffer {
    func commit(_ code: () -> Void) {
        code()
        commit()
    }
}

struct MTLComputeArgumentEncoder {
    var compute: any MTLComputeCommandEncoder
}

extension MTLSizeAndAlign {
    var aligned: Self {
        .init(
            size: size.align(by: align),
            align: align
        )
    }
}
