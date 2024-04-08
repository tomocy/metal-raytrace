// tomocy

#pragma once

namespace Coordinate {
struct InScreen {
public:
    InScreen() = default;

    explicit InScreen(uint2 value)
        : value_(value)
    {
    }

public:
    thread uint2& value() { return value_; }
    const thread uint2& value() const { return value_; }

private:
    uint2 value_;
};

struct InFace {
public:
    static InFace from(const thread InScreen& coordinate, const uint size)
    {
        return InFace(coordinate.value() % size);
    }

public:
    InFace() = default;

    explicit InFace(uint2 value)
        : value_(value)
    {
    }

public:
    thread uint2& value() { return value_; }
    const thread uint2& value() const { return value_; }

private:
    uint2 value_;
};

struct InUV {
public:
    static InUV from(const thread InScreen& coordinate, const uint2 size)
    {
        return InUV(
            float2(coordinate.value()) / float2(size)
        );
    }

    static InUV from(const thread InFace& coordinate, const uint size)
    {
        return InUV(
            float2(coordinate.value()) / float2(size)
        );
    }

public:
    InUV() = default;

    explicit InUV(float2 value)
        : value_(value)
    {
    }

public:
    thread float2& value() { return value_; }
    const thread float2& value() const { return value_; }

private:
    float2 value_;
};

struct InNDC {
public:
    static InNDC from(const thread InUV& coordinate, const float z)
    {
        return InNDC(
            float3(
                float2(coordinate.value().x * 2 - 1, coordinate.value().y * -2 + 1),
                z
            )
        );
    }

    static InNDC from(const thread InUV& coordinate, const uint face)
    {
        float3 inNDC = from(coordinate, float(0)).value();

        switch (face) {
        case 0:
            inNDC = float3(1, inNDC.y, -inNDC.x);
            break;
        case 1:
            inNDC = float3(-1, inNDC.y, inNDC.x);
            break;
        case 2:
            inNDC = float3(inNDC.x, 1, -inNDC.y);
            break;
        case 3:
            inNDC = float3(inNDC.x, -1, inNDC.y);
            break;
        case 4:
            inNDC = float3(inNDC.x, inNDC.y, 1);
            break;
        case 5:
            inNDC = float3(-inNDC.x, inNDC.y, -1);
            break;
        default:
            inNDC = 0;
            break;
        }

        return InNDC(inNDC);
    }

public:
    InNDC() = default;

    explicit InNDC(float3 value)
        : value_(value)
    {
    }

public:
    thread float3& value() { return value_; }
    const thread float3& value() const { return value_; }

private:
    float3 value_;
};
}
