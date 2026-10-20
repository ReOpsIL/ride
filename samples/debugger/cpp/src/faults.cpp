#include <cstdio>
#include <optional>
#include <stdexcept>
#include <string>

#include "scenarios.hpp"

namespace {

std::optional<int> parse_quantity(const std::string& text) {
    try {
        std::size_t used = 0;
        int value = std::stoi(text, &used);
        return used == text.size() ? std::optional<int>(value) : std::nullopt;
    } catch (const std::invalid_argument&) {
        return std::nullopt;
    }
}

int validate(int value) {
    if (value < 0) {
        throw std::runtime_error("negative value " + std::to_string(value));
    }
    return value;
}

}

void lab::faults() {
    std::optional<int> parsed = parse_quantity("12");
    std::optional<int> rejected = parse_quantity("twelve");
    bool caught = false;
    try {
        validate(-1);
    } catch (const std::runtime_error& error) {
        caught = true;
        std::printf("faults: caught \"%s\"\n", error.what());
    }
    std::printf("faults: parsed=%d rejected=%d caught=%d\n", parsed.value_or(-1), !rejected.has_value(), caught);
}
