#include <stdio.h>

#include "order.h"
#include "scenarios.h"

static int discount(int amount, int quantity) {
    int percent = quantity >= 3 ? 10 : 0;
    int reduced = amount - amount * percent / 100;
    return reduced;
}

static int price(const order_t *order) {
    int base = order->quantity * order->unit_price;
    int reduced = discount(base, order->quantity);
    return reduced;
}

static int apply_tax(int amount) {
    int tax = amount / 5;
    return amount + tax;
}

int order_checkout(const order_t *order) {
    int subtotal = price(order);
    int total = apply_tax(subtotal);
    return total;
}

void lab_stack(void) {
    order_t order = {.id = 7, .quantity = 3, .unit_price = 250, .currency = "EUR"};
    int receipt = order_checkout(&order);
    printf("stack: order %d costs %d %s\n", order.id, receipt, order.currency);
}
