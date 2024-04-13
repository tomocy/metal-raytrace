// tomocy

extension Int {
    func align(by alignment: Self) -> Self {
        return (self + alignment - 1) / alignment * alignment
    }
}
