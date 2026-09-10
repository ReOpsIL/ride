#include <registry.h>

namespace geo {

void Registry::add(const std::string &key, Shape *shape) {
    this->shapes_[key] = shape;
}

Shape *Registry::find(const std::string &key) const {
    auto it = shapes_.find(key);
    return it == shapes_.end() ? nullptr : it->second;
}

std::size_t Registry::size() const {
    return shapes_.size();
}

}

