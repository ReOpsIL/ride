#pragma once

#include <string>

namespace lab {

class Order {
public:
    Order(int id, int quantity, int unit_price);

    int checkout() const;
    int id() const { return id_; }

private:
    int price() const;
    int discount(int amount) const;
    static int apply_tax(int amount);

    int id_;
    int quantity_;
    int unit_price_;
    std::string currency_ = "EUR";
};

}
