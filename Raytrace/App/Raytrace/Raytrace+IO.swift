// tomocy

import Metal

extension Raytrace {
    enum IO {}
}

extension Raytrace.IO {
    typealias Writable = _ShaderIOWritable
}

extension Raytrace.IO {
    static func writable<T>(_ target: T) -> some Raytrace.IO.Writable {
        return DefaultWritable.init(value: target)
    }

    static func writable(_ target: some Raytrace.IO.Writable) -> some Raytrace.IO.Writable {
        return target
    }
}

protocol _ShaderIOWritable {
    func write(to destination: UnsafeMutableRawPointer)
}

extension Raytrace.IO.Writable {
    func write(to destination: UnsafeMutableRawPointer) {
        Raytrace.IO.writable(self).write(to: destination)
    }
}

extension Raytrace.IO.Writable {
    func write(to destination: MTLBuffer, by offset: Int = 0) {
        write(to: destination.contents().advanced(by: offset))
    }
}

extension Raytrace.IO {
    fileprivate struct DefaultWritable<T> {
        var value: T
    }
}

extension Raytrace.IO.DefaultWritable: Raytrace.IO.Writable {
    func write(to destination: UnsafeMutableRawPointer) {
        withUnsafeBytes(of: value) { bytes in
            destination.copy(from: bytes.baseAddress!, count: bytes.count)
        }
    }
}

extension Array: Raytrace.IO.Writable {
    func write(to destination: UnsafeMutableRawPointer) {
        withUnsafeBytes { bytes in
            destination.copy(from: bytes.baseAddress!, count: bytes.count)
        }
    }

    func write(to destination: UnsafeMutableRawPointer) where Element: Raytrace.IO.Writable {
        enumerated().forEach { i, v in
            v.write(to: destination + MemoryLayout<Element>.stride * i)
        }
    }
}
