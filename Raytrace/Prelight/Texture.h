// tomocy

#pragma once

#include "Coordinate.h"
#include <metal_stdlib>

namespace Texture {
template <typename T, metal::access Access>
struct Cube {
public:
    using Raw = metal::texturecube<T, Access>;

public:
    thread Raw& raw() { return raw_; }
    constant Raw& raw() constant { return raw_; }

private:
    Raw raw_;

public:
    uint size() constant { return raw().get_width(); }

public:
    uint faceFor(const thread Coordinate::InScreen<uint2>& coordinate) constant {
        return coordinate.value().y / size();
    }

    Coordinate::InFace<uint2> coordinateInFace(const thread Coordinate::InScreen<uint2>& coordinate) constant {
        return Coordinate::inFace(coordinate.value() % size());
    }

public:
    metal::vec<T, 4> readInFace(const thread Coordinate::InScreen<uint2>& coordinate) constant {
        return raw().read(coordinateInFace(coordinate).value(), faceFor(coordinate));
    }

    void writeInFace(
        const thread metal::vec<T, 4>& color,
        const thread Coordinate::InScreen<uint2>& coordinate,
        const uint lod = 0
    ) constant {
        raw().write(color, coordinateInFace(coordinate).value(), faceFor(coordinate), lod);
    }
};
}
