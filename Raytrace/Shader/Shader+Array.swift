// tomocy

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
