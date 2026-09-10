#pragma once

#include <string>
#include <vector>

#include "registry.h"

namespace geo {

using Real = double;

constexpr Real PI = 3.141592653589793;

template <typename T>
concept Scalable = requires(T t, Real f) { t.scale(f); };

class Shape {
public:
    explicit Shape(std::string name);
    virtual ~Shape() = default;

    virtual Real area() const = 0;
    virtual Real perimeter() const = 0;
    virtual void scale(Real factor) = 0;

    const std::string &name() const;
    std::string describe() const;

protected:
    std::string name_;
};

class Circle : public Shape {
public:
    Circle(std::string name, Real radius);

    Real area() const override;
    Real perimeter() const override;
    void scale(Real factor) override;

    Real radius() const;

private:
    Real radius_;
};

class Rect : public Shape {
public:
    Rect(std::string name, Real width, Real height);

    Real area() const override;
    Real perimeter() const override;
    void scale(Real factor) override;

    bool is_square() const;

private:
    Real width_;
    Real height_;
};

template <Scalable S>
void scale_all(std::vector<S> &shapes, Real factor) {
    for (auto &shape : shapes) {
        shape.scale(factor);
    }
}

Real total_area(const std::vector<const Shape *> &shapes);

}
