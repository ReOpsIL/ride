#ifndef DEMO_UTIL_H
#define DEMO_UTIL_H

#include <stddef.h>

struct buffer {
    char *data;
    size_t len;
    size_t cap;
};

struct buffer buffer_new(size_t cap);
void buffer_append(struct buffer *b, const char *text);
void buffer_free(struct buffer *b);

#endif
