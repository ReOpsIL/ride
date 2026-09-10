CXX ?= clang++
CXXFLAGS ?= -std=c++20 -Wall -Wextra -Iinclude
SRC := src/main.cpp src/shapes.cpp src/registry.cpp
OBJ := $(SRC:src/%.cpp=build/%.o)

all: build/demo

build/demo: $(OBJ)
	$(CXX) $(CXXFLAGS) -o $@ $^

build/%.o: src/%.cpp
	@mkdir -p build
	$(CXX) $(CXXFLAGS) -c $< -o $@

compile_commands: build/compile_commands.json

build/compile_commands.json: Makefile
	@mkdir -p build
	@printf '[\n' > $@
	@sep=""; for f in $(SRC); do \
	  printf '%s  {"directory": "%s", "file": "%s", "command": "$(CXX) $(CXXFLAGS) -c %s -o build/$$(basename $$f .cpp).o"}' "$$sep" "$(CURDIR)" "$$f" "$$f" >> $@; \
	  sep=",\n"; \
	done
	@printf '\n]\n' >> $@

run: build/demo
	./build/demo

clean:
	rm -rf build/demo build/*.o

.PHONY: all compile_commands run clean
