// tomocy

import Metal

extension Raytrace {
    struct Acceleration {
        var structure: any MTLAccelerationStructure
        var meshes: [Mesh]
        var primitives: [Primitive.Instance]
    }
}
