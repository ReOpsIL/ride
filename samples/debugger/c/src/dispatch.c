#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "scenarios.h"

typedef struct shape shape_t;

typedef struct {
    const char *name;
    double (*area)(const shape_t *shape);
} shape_ops_t;

struct shape {
    const shape_ops_t *ops;
    double size;
};

static double circle_area(const shape_t *shape) {
    double r = shape->size;
    return 3.14159265358979 * r * r;
}

static double square_area(const shape_t *shape) {
    double s = shape->size;
    return s * s;
}

static const shape_ops_t circle_ops = {"circle", circle_area};
static const shape_ops_t square_ops = {"square", square_area};

static int apply(int (*op)(int), int value) {
    return op(value);
}

static int negate(int value) {
    return -value;
}

static int by_length(const void *left, const void *right) {
    size_t a = strlen(*(const char *const *)left);
    size_t b = strlen(*(const char *const *)right);
    return (a > b) - (a < b);
}

void lab_dispatch(void) {
    shape_t shapes[2] = {{&circle_ops, 1.0}, {&square_ops, 2.0}};
    double total = 0.0;
    for (int i = 0; i < 2; ++i) {
        double area = shapes[i].ops->area(&shapes[i]);
        printf("dispatch: %s has area %.2f\n", shapes[i].ops->name, area);
        total += area;
    }
    int negated = apply(negate, 16);
    const char *words[] = {"pear", "fig", "banana"};
    qsort(words, 3, sizeof words[0], by_length);
    printf("dispatch: total=%.2f negated=%d first=%s\n", total, negated, words[0]);
}
