static int helper(int a) {
    int unused_local = 0;
    return a + a;
}

static int twice(int a) { return a + a; }
static int twice(int b) { return b * 2; }

int main() { return helper(2); }
