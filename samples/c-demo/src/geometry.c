#include <geometry.h>

#include <math.h>
#include <stdio.h>

double point_distance(point_t a, point_t b) {
    double dx = a.x - b.x;
    double dy = a.y - b.y;
    return sqrt(SQUARE(dx) + SQUARE(dy));
}

double rect_area(const rect_t *r) {
    return r->width * r->height;
}

int rect_contains(const rect_t *r, point_t p) {
    return p.x >= r->origin.x && p.x <= r->origin.x + r->width && p.y >= r->origin.y &&
           p.y <= r->origin.y + r->height;
}

void shape_describe(const struct shape *s, char *out, unsigned long cap) {
    switch (s->kind) {
    case SHAPE_POINT:
        snprintf(out, cap, "%s: point (%.1f, %.1f)", s->label, s->as.point.x, s->as.point.y);
        break;
    case SHAPE_RECT:
        snprintf(out, cap, "%s: rect %.1fx%.1f", s->label, s->as.rect.width, s->as.rect.height);
        break;
    }
}
