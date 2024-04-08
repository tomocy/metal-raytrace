// tomocy

#pragma once

namespace Coordinate {
template <typename T>
struct InScreen {
public:
    explicit InScreen(T value) : value_(value) {}

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
    explicit InFace(T value) : value_(value) {}

public:
    thread T& value() { return value_; }
    const thread T& value() const { return value_; }

private:
    T value_;
};

template <typename T>
InFace<T> inFace(T value) { return InFace<T>(value); }
}
