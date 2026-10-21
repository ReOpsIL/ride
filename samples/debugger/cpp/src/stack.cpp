#include <cstdio>

#include "order.hpp"
#include "scenarios.hpp"

lab::Order::Order(int id, int quantity, int unit_price) : id_(id), quantity_(quantity), unit_price_(unit_price) {}

int lab::Order::checkout() const {
    int subtotal = price();
    int total = apply_tax(subtotal);
    return total;
}

int lab::Order::price() const {
    int base = quantity_ * unit_price_;
    int reduced = discount(base);
    return reduced;
}

int lab::Order::discount(int amount) const {
    int percent = quantity_ >= 3 ? 10 : 0;
    int reduced = amount - amount * percent / 100;
    return reduced;
}

int lab::Order::apply_tax(int amount) {
    int tax = amount / 5;
    return amount + tax;
}

void lab::stack() {
    Order order(7, 3, 250);
    int receipt = order.checkout();
    std::printf("stack: order %d costs %d\n", order.id(), receipt);
}
