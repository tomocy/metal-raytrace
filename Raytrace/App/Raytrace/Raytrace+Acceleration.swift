// tomocy

import Metal

extension Raytrace {
    struct Acceleration {
        var structure: any MTLAccelerationStructure
        var meshes: [Mesh]
        var primitives: [Primitive.Instance]
    }
}

extension Raytrace.Acceleration {
    struct ForGPU {
        var structure: MTLResourceID
        var meshes: UInt64
        var primitives: UInt64
    }
}
