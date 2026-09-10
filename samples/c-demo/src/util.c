#include "util.h"

#include <stdlib.h>
#include <string.h>

struct buffer buffer_new(size_t cap) {
    struct buffer b;
    b.data = malloc(cap);
    b.len = 0;
    b.cap = cap;
    if (b.data && cap > 0) {
        b.data[0] = '\0';
    }
    return b;
}

void buffer_append(struct buffer *b, const char *text) {
    size_t n = strlen(text);
    if (b->len + n + 1 > b->cap) {
        return;
    }
    memcpy(b->data + b->len, text, n + 1);
    b->len += n;
}

void buffer_free(struct buffer *b) {
    free(b->data);
    b->data = NULL;
    b->len = 0;
    b->cap = 0;
}
