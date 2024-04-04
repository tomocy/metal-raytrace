// tomocy

import Metal

extension Shader {
    enum IO {}
}

extension Shader.IO {
    typealias Writable = _ShaderIOWritable
}

extension Shader.IO {
    static func writable<T>(_ target: T) -> some Shader.IO.Writable {
        return Shader.IO.DefaultWritable.init(value: target)
    }

    static func writable(_ target: some Shader.IO.Writable) -> some Shader.IO.Writable {
        return target
    }
}

protocol _ShaderIOWritable {
    func write(to destination: UnsafeMutableRawPointer)
}

extension Shader.IO.Writable {
    func write(to destination: UnsafeMutableRawPointer) {
        Shader.IO.writable(self).write(to: destination)
    }
}

extension Shader.IO.Writable {
    func write(to destination: MTLBuffer, by offset: Int = 0) {
        write(to: destination.contents().advanced(by: offset))
    }
}

extension Shader.IO {
    fileprivate struct DefaultWritable<T> {
        var value: T
    }
}

extension Shader.IO.DefaultWritable: Shader.IO.Writable {
    func write(to destination: UnsafeMutableRawPointer) {
        withUnsafeBytes(of: value) { bytes in
            destination.copy(from: bytes.baseAddress!, count: bytes.count)
        }
    }
}

extension Array: Shader.IO.Writable {
    func write(to destination: UnsafeMutableRawPointer) {
        withUnsafeBytes { bytes in
            destination.copy(from: bytes.baseAddress!, count: bytes.count)
        }
    }

    func write(to destination: UnsafeMutableRawPointer) where Element: Shader.IO.Writable {
        enumerated().forEach { i, v in
            v.write(to: destination + MemoryLayout<Element>.stride * i)
        }
    }
}
