#include <errno.h>
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>

#include "scenarios.h"

static jmp_buf recovery;

static int parse_quantity(const char *text, int *out) {
    char *end = NULL;
    errno = 0;
    long value = strtol(text, &end, 10);
    if (errno != 0 || end == text || *end != '\0') {
        return -1;
    }
    *out = (int)value;
    return 0;
}

static int validate(int value) {
    if (value < 0) {
        longjmp(recovery, value);
    }
    return value;
}

void lab_faults(void) {
    int parsed = 0;
    int ok = parse_quantity("12", &parsed);
    int rejected = 0;
    int failed = parse_quantity("twelve", &rejected);
    int code = setjmp(recovery);
    if (code == 0) {
        validate(-1);
    }
    printf("faults: parsed=%d (%d) rejected=%d jumped back with %d\n", parsed, ok, failed, code);
}
