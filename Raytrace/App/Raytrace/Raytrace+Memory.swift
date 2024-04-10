// tomocy

extension UnsafeMutableRawPointer {
    func copy(from base: UnsafeRawPointer, count: Int, offset: Int = 0) {
        advanced(by: offset).copyMemory(
            from: base,
            byteCount: count
        )
    }
}

extension UnsafeMutableRawPointer {
    func toArray<T>(count: Int) -> [T] {
        return [T].init(
            UnsafeBufferPointer.init(
                start: bindMemory(to: T.self, capacity: count),
                count: count
            )
        )
    }
}
