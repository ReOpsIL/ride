#include <algorithm>
#include <cstdio>
#include <functional>
#include <memory>
#include <string>
#include <vector>

#include "scenarios.hpp"
#include "shapes.hpp"

double lab::Circle::area() const {
    double r = radius_;
    return 3.14159265358979 * r * r;
}

double lab::Square::area() const {
    double s = side_;
    return s * s;
}

namespace {

int apply(int (*op)(int), int value) {
    return op(value);
}

int negate(int value) {
    return -value;
}

}

void lab::dispatch() {
    std::vector<std::unique_ptr<Shape>> shapes;
    shapes.push_back(std::make_unique<Circle>(1.0));
    shapes.push_back(std::make_unique<Square>(2.0));
    double total = 0.0;
    for (const auto& shape : shapes) {
        double area = shape->area();
        std::printf("dispatch: %s has area %.2f\n", shape->name().c_str(), area);
        total += area;
    }
    int factor = 3;
    auto scale = [factor](int value) {
        int scaled = value * factor;
        return scaled + 1;
    };
    std::function<int(int)> stored = scale;
    int scaled = stored(5);
    int negated = apply(negate, scaled);
    std::vector<std::string> words{"pear", "fig", "banana"};
    std::sort(words.begin(), words.end(), [](const std::string& a, const std::string& b) {
        return a.size() < b.size();
    });
    std::printf("dispatch: total=%.2f scaled=%d negated=%d first=%s\n", total, scaled, negated, words.front().c_str());
}
