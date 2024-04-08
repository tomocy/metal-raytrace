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
    static InFace from(const thread InScreen& inScreen, const uint size);

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
