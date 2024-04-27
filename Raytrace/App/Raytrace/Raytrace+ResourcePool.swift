// tomocy

import Metal

extension Raytrace {
    struct ResourcePool {
        var buffers: Buffers = .init()
    }
}

extension Raytrace.ResourcePool {
    class Buffers {
        private var buffers: [String: any MTLBuffer] = [:]
    }
}

extension Raytrace.ResourcePool.Buffers {
    func take(at key: String, or buffer: () -> (any MTLBuffer)?) -> (any MTLBuffer)? {
        if let buffer = buffers[key] {
            return buffer
        }
        
        let buffer = buffer()
        buffers[key] = buffer

        return buffer
    }
}
