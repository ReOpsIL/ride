#include <geometry.h>

#include <stdio.h>

#include "util.h"

static struct shape shapes[MAX_SHAPES];
static int shape_count = 0;

static struct shape *add_point(const char *label, double x, double y) {
    struct shape *s = &shapes[shape_count++];
    s->kind = SHAPE_POINT;
    s->as.point.x = x;
    s->as.point.y = y;
    s->label = label;
    return s;
}

static struct shape *add_rect(const char *label, rect_t r) {
    struct shape *s = &shapes[shape_count++];
    s->kind = SHAPE_RECT;
    s->as.rect = r;
    s->label = label;
    return s;
}

int main(void) {
    point_t origin = {0.0, 0.0};
    point_t far = {3.0, 4.0};
    rect_t box = {origin, 10.0, 5.0};

    add_point("origin", origin.x, origin.y);
    add_rect("box", box);

    struct buffer out = buffer_new(256);
    char line[128];
    for (int i = 0; i < shape_count; i++) {
        shape_describe(&shapes[i], line, sizeof line);
        buffer_append(&out, line);
        buffer_append(&out, "\n");
    }
    printf("%s", out.data);
    printf("distance %.1f, area %.1f, contains %d\n", point_distance(origin, far), rect_area(&box),
           rect_contains(&box, far));
    printf("demo %s with up to %d shapes\n", DEMO_VERSION, MAX_SHAPES);
    buffer_free(&out);
    return 0;
}
