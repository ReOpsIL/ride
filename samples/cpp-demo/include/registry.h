#pragma once

#include <map>
#include <string>

namespace geo {

class Shape;

class Registry {
public:
    void add(const std::string &key, Shape *shape);
    Shape *find(const std::string &key) const;
    std::size_t size() const;

private:
    std::map<std::string, Shape *> shapes_;
};

}
