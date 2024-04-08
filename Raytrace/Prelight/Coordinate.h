// tomocy

#pragma once

namespace Coordinate {
template <typename T>
struct InScreen {
public:
    InScreen() = default;

    explicit InScreen(T value)
        : value_(value)
    {
    }

public:
    thread T& value() { return value_; }
    const thread T& value() const { return value_; }

private:
    T value_;
};

template <typename T>
InScreen<T> inScreen(T value) { return InScreen<T>(value); }

template <typename T>
struct InFace {
public:
    InFace() = default;

    explicit InFace(T value)
        : value_(value)
    {
    }

public:
    thread T& value() { return value_; }
    const thread T& value() const { return value_; }

private:
    T value_;
};

template <typename T>
InFace<T> inFace(T value) { return InFace<T>(value); }

template <typename T>
struct InUV {
public:
    InUV() = default;

    explicit InUV(T value)
        : value_(value)
    {
    }

public:
    thread T& value() { return value_; }
    const thread T& value() const { return value_; }

private:
    T value_;
};

template <typename T>
InUV<T> inUV(T value) { return InUV<T>(value); }

template <typename T>
struct InNDC {
public:
    InNDC() = default;

    explicit InNDC(T value)
        : value_(value)
    {
    }

public:
    thread T& value() { return value_; }
    const thread T& value() const { return value_; }

private:
    T value_;
};

template <typename T>
InNDC<T> inNDC(T value) { return InNDC<T>(value); }
}
