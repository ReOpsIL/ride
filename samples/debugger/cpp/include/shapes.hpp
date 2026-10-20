#pragma once

#include <string>

namespace lab {

class Shape {
public:
    explicit Shape(std::string name) : name_(std::move(name)) {}
    virtual ~Shape() = default;

    virtual double area() const = 0;
    const std::string& name() const { return name_; }

private:
    std::string name_;
};

class Circle : public Shape {
public:
    explicit Circle(double radius) : Shape("circle"), radius_(radius) {}
    double area() const override;

private:
    double radius_;
};

class Square : public Shape {
public:
    explicit Square(double side) : Shape("square"), side_(side) {}
    double area() const override;

private:
    double side_;
};

}
