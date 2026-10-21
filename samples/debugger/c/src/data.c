#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "scenarios.h"

typedef struct {
    double x;
    double y;
} point_t;

typedef struct {
    point_t origin;
    point_t size;
    char label[16];
} rect_t;

typedef enum { SHAPE_EMPTY, SHAPE_CIRCLE, SHAPE_POLYGON } shape_kind_t;

typedef struct {
    shape_kind_t kind;
    union {
        double radius;
        struct {
            const point_t *points;
            int count;
        } polygon;
    } as;
} shape_t;

typedef struct node {
    int value;
    struct node *next;
} node_t;

static node_t *push(node_t *head, int value) {
    node_t *node = malloc(sizeof *node);
    if (node == NULL) {
        return head;
    }
    node->value = value;
    node->next = head;
    return node;
}

static void release(node_t *head) {
    while (head != NULL) {
        node_t *next = head->next;
        free(head);
        head = next;
    }
}

static point_t corner(const rect_t *rect) {
    point_t far = {rect->origin.x + rect->size.x, rect->origin.y + rect->size.y};
    return far;
}

void lab_data(void) {
    point_t point = {1.5, -2.0};
    rect_t rect = {point, {4.0, 3.0}, "window"};
    point_t outline[3] = {point, rect.size, {0.0, 0.0}};
    shape_t shapes[3] = {
        {.kind = SHAPE_EMPTY},
        {.kind = SHAPE_CIRCLE, .as.radius = 2.5},
        {.kind = SHAPE_POLYGON, .as.polygon = {outline, 3}},
    };
    int fixed[8] = {1, 1, 2, 3, 5, 8, 13, 21};
    int grid[3][4] = {{1, 2, 3, 4}, {5, 6, 7, 8}, {9, 10, 11, 12}};
    unsigned large[250];
    for (unsigned i = 0; i < 250; ++i) {
        large[i] = i;
    }
    node_t *list = NULL;
    for (int value = 1; value <= 4; ++value) {
        list = push(list, value * 100);
    }
    const char *greeting = "hello, debugger";
    char *copy = strdup(greeting);
    point_t *heap = malloc(sizeof *heap);
    if (heap != NULL) {
        *heap = corner(&rect);
    }
    printf("data: %s at (%.1f, %.1f), kind %d, fixed %d, grid %d, large %u, head %d, copy %s\n", rect.label,
           heap ? heap->x : 0.0, heap ? heap->y : 0.0, shapes[2].kind, fixed[7], grid[2][3], large[249],
           list ? list->value : 0, copy ? copy : "");
    free(heap);
    free(copy);
    release(list);
}
