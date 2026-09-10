CC ?= clang
CFLAGS ?= -std=c17 -Wall -Wextra -Iinclude
SRC := src/main.c src/geometry.c src/util.c
OBJ := $(SRC:src/%.c=build/%.o)

all: build/demo

build/demo: $(OBJ)
	$(CC) $(CFLAGS) -o $@ $^ -lm

build/%.o: src/%.c
	@mkdir -p build
	$(CC) $(CFLAGS) -c $< -o $@

compile_commands: build/compile_commands.json

build/compile_commands.json: Makefile
	@mkdir -p build
	@printf '[\n' > $@
	@sep=""; for f in $(SRC); do \
	  printf '%s  {"directory": "%s", "file": "%s", "command": "$(CC) $(CFLAGS) -c %s -o build/$$(basename $$f .c).o"}' "$$sep" "$(CURDIR)" "$$f" "$$f" >> $@; \
	  sep=",\n"; \
	done
	@printf '\n]\n' >> $@

run: build/demo
	./build/demo

clean:
	rm -rf build/demo build/*.o

.PHONY: all compile_commands run clean
