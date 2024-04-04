// tomocy

extension UnsafeMutableRawPointer {
    func copy(from base: UnsafeRawPointer, count: Int, offset: Int = 0) {
        advanced(by: offset).copyMemory(
            from: base,
            byteCount: count
        )
    }
}
