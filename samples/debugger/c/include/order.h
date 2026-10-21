#ifndef LAB_ORDER_H
#define LAB_ORDER_H

typedef struct {
    int id;
    int quantity;
    int unit_price;
    const char *currency;
} order_t;

int order_checkout(const order_t *order);

#endif
