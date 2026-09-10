#include <shapes.hpp>

#include <cmath>
#include <sstream>

namespace geo {

Shape::Shape(std::string name) : name_(std::move(name)) {}

const std::string &Shape::name() const {
    return name_;
}

std::string Shape::describe() const {
    std::ostringstream out;
    out << this->name_ << ": area " << this->area() << ", perimeter " << this->perimeter();
    return out.str();
}

Circle::Circle(std::string name, Real radius) : Shape(std::move(name)), radius_(radius) {}

Real Circle::area() const {
    return PI * radius_ * radius_;
}

Real Circle::perimeter() const {
    return 2 * PI * radius_;
}

void Circle::scale(Real factor) {
    this->radius_ *= factor;
}

Real Circle::radius() const {
    return radius_;
}

Rect::Rect(std::string name, Real width, Real height)
    : Shape(std::move(name)), width_(width), height_(height) {}

Real Rect::area() const {
    return width_ * height_;
}

Real Rect::perimeter() const {
    return 2 * (width_ + height_);
}

void Rect::scale(Real factor) {
    this->width_ *= factor;
    this->height_ *= factor;
}

bool Rect::is_square() const {
    return std::fabs(width_ - height_) < 1e-9;
}

Real total_area(const std::vector<const Shape *> &shapes) {
    Real sum = 0;
    for (const Shape *shape : shapes) {
        sum += shape->area();
    }
    return sum;
}

}
