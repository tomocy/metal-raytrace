// tomocy

import Metal

extension Shader {
    enum Metal {}
}

extension Shader.Metal {
    static func bufferBuildable<T>(_ value: T) -> some BufferBuildable {
        return DefaultBufferAllocatable.init(value: value)
    }

    static func bufferBuildable(_ value: some BufferBuildable) -> some BufferBuildable {
        return value
    }
}

extension Shader.Metal {
    typealias BufferBuildable = _ShaderMetalBufferBuildable
}

protocol _ShaderMetalBufferBuildable {
    func build(with device: some MTLDevice, label: String?, options: MTLResourceOptions) -> (any MTLBuffer)?
}

extension Shader.Metal.BufferBuildable {
    func build(with device: some MTLDevice, label: String? = nil, options: MTLResourceOptions = []) -> (any MTLBuffer)? {
        return build(with: device, label: label, options: options)
    }
}

extension Shader.Metal {
    struct DefaultBufferAllocatable<T> {
        var value: T
    }
}

extension Shader.Metal.DefaultBufferAllocatable: Shader.Metal.BufferBuildable {
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

extension Array: Shader.Metal.BufferBuildable {
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
