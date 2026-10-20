#include <stdio.h>

#include "scenarios.h"

static int twice(int value) {
    int result = value * 2;
    return result;
}

static int offset(int value, int by) {
    int moved = value + by;
    return moved;
}

static int combine(int a, int b, int c) {
    int partial = twice(a) + b;
    int total = offset(partial, c);
    return total;
}

void lab_stepping(void) {
    int base = 10;
    int doubled = twice(base);
    int shifted = offset(doubled, 3);
    int nested = offset(twice(base), twice(3));
    int total = combine(base, doubled, shifted);
    printf("stepping: base=%d doubled=%d shifted=%d nested=%d total=%d\n", base, doubled, shifted, nested, total);
}
