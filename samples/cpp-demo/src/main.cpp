#include <shapes.hpp>

#include <iostream>
#include <memory>
#include <vector>

int main() {
    geo::Circle circle("wheel", 2.0);
    geo::Rect rect("door", 1.0, 2.0);
    geo::Rect square("tile", 3.0, 3.0);

    geo::Registry registry;
    registry.add(circle.name(), &circle);
    registry.add(rect.name(), &rect);
    registry.add(square.name(), &square);

    std::vector<const geo::Shape *> all = {&circle, &rect, &square};
    for (const geo::Shape *shape : all) {
        std::cout << shape->describe() << '\n';
    }

    std::vector<geo::Rect> rects = {rect, square};
    geo::scale_all(rects, 2.0);
    for (const auto &r : rects) {
        std::cout << r.name() << (r.is_square() ? " is square" : " is not square") << '\n';
    }

    geo::Shape *found = registry.find("wheel");
    if (found != nullptr) {
        found->scale(0.5);
        std::cout << found->name() << " radius now " << circle.radius() << '\n';
    }

    std::cout << "registry holds " << registry.size() << " shapes, total area "
              << geo::total_area(all) << '\n';
    return 0;
}
