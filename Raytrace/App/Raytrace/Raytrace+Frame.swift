// tomocy

import Metal

extension Raytrace {
    struct Frame {
        var id: UInt32
    }
}

extension Raytrace.Frame {
    func encode(with encoder: some MTLArgumentEncoder, at index: Int) {
        let buffer = encoder.constantData(at: index)
        Raytrace.IO.writable(self).write(to: buffer)
    }
}
