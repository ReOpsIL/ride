#include <array>
#include <cstdio>
#include <map>
#include <memory>
#include <numeric>
#include <optional>
#include <string>
#include <tuple>
#include <variant>
#include <vector>

#include "scenarios.hpp"

namespace {

struct Point {
    double x;
    double y;
};

struct Rect {
    Point origin;
    Point size;
    std::string label;
};

enum class Kind { Empty, Circle, Polygon };

struct Shape {
    Kind kind;
    std::variant<std::monostate, double, std::vector<Point>> detail;
};

Point corner(const Rect& rect) {
    return Point{rect.origin.x + rect.size.x, rect.origin.y + rect.size.y};
}

}

void lab::data() {
    Point point{1.5, -2.0};
    Rect rect{point, {4.0, 3.0}, "window"};
    std::vector<Shape> shapes{
        {Kind::Empty, std::monostate{}},
        {Kind::Circle, 2.5},
        {Kind::Polygon, std::vector<Point>{point, rect.size, {0.0, 0.0}}},
    };
    std::optional<Point> found = point;
    std::optional<Point> missing;
    std::array<int, 8> fixed{1, 1, 2, 3, 5, 8, 13, 21};
    std::tuple<int, char, std::string> tuple{42, 'L', "slice"};
    std::vector<unsigned> large(250);
    std::iota(large.begin(), large.end(), 0u);
    std::map<std::string, int> inventory{{"apples", 12}, {"pears", 3}};
    auto shared = std::make_shared<std::vector<std::string>>(std::vector<std::string>{"first"});
    auto alias = shared;
    alias->push_back("second");
    auto owned = std::make_unique<Rect>(Rect{point, point, "owned"});
    const char* raw = rect.label.c_str();
    Point far = corner(rect);
    std::printf("data: %s at (%.1f, %.1f), %zu shapes, found %d, missing %d, fixed %zu, tuple %d, large %zu, inventory %zu, shared %ld/%zu, owned %s\n",
                raw, far.x, far.y, shapes.size(), found.has_value(), !missing.has_value(), fixed.size(),
                std::get<0>(tuple), large.size(), inventory.size(), shared.use_count(), shared->size(),
                owned->label.c_str());
}
