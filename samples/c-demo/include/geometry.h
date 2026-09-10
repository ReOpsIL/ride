#ifndef DEMO_GEOMETRY_H
#define DEMO_GEOMETRY_H

#include "config.h"

typedef struct point {
    double x;
    double y;
} point_t;

typedef struct {
    point_t origin;
    double width;
    double height;
} rect_t;

enum shape_kind { SHAPE_POINT, SHAPE_RECT };

struct shape {
    enum shape_kind kind;
    union {
        point_t point;
        rect_t rect;
    } as;
    const char *label;
};

double point_distance(point_t a, point_t b);
double rect_area(const rect_t *r);
int rect_contains(const rect_t *r, point_t p);
void shape_describe(const struct shape *s, char *out, unsigned long cap);

#endif
