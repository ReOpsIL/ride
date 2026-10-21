# Debugger lab

Three small programs, in Rust, C++ and C, for checking Ride's debugger by hand. They are written to be stepped through: stepping controls, the call stack, variables and watches, breakpoint conditions, threads, exceptions, Pause and attaching to a forked child. All three run the same ten scenarios with the same function names and print the same results, so one checklist covers all three languages.

```
rust/   Cargo crate `debugger-lab`, one module per scenario (src/<scenario>.rs)
cpp/    CMake, C++20, one file per scenario (src/<scenario>.cpp), classes in include/
c/      CMake, C17 + pthreads, one file per scenario (src/<scenario>.c)
```

Open `samples/debugger` itself to get all three as projects in one window (the active project follows the editor), or open one language folder on its own. Debug (⌃⌘R) builds first: Cargo `dev` and CMake `Debug`, both `-O0 -g`. You need `lldb-dap`; Xcode's copy is found through `xcrun`.

The first nine scenarios run by default, in order, and each prints `== <scenario> ==` first. To run a single one, put its name in **Run › Edit Configurations… › Program Arguments** (`stepping`, `stack`, `recursion`, `loops`, `data`, `dispatch`, `threads`, `faults`, `heartbeat`). `fork` runs only when named. From a shell: `cargo run -- stack`, or `cmake -S . -B build/Debug && cmake --build build/Debug && build/Debug/debugger-lab stack`.

Set breakpoints by clicking the gutter. The steps below point at code by function name and statement, not line number.

## 1. stepping: Step Over, Step Into, Step Out

Breakpoint on `let base = 10;` / `int base = 10;` in `stepping` (`run` in Rust).

- **Step Over (F8)** goes line by line. `doubled` becomes 20 and `shifted` 23 in Variables.
- On `nested = offset(twice(base), twice(3))` (`double` in Rust), **Step Into (F7)** enters `twice(10)` first. **Step Out (⇧F8)** returns to the same line. Step Into again enters `twice(3)`, and a third Step Into enters `offset(20, 6)`. Rust evaluates arguments left to right; C and C++ leave the order to the compiler, and clang also goes left to right.
- On `total = combine(…)`, Step Into, then Step Into again on `partial = twice(a) + b`. Step Out returns into `combine` mid-expression, not to `stepping`.
- Inside `twice` (`double`), Step Over past the last line returns to the caller.
- After each step the stopped line keeps the blue marked-line tint, and the editor follows when a step lands in another function.

Expect `stepping: base=10 doubled=20 shifted=23 nested=26 total=63`.

## 2. stack: call stack and frame selection

Breakpoint on `reduced = amount - amount * percent / 100` in `discount`.

- Frames, top first: `discount`, `price`, `checkout`, `stack`/`run`, `main`. Rust adds runtime frames (`FnOnce::call_once`, `lang_start`, …) below `main`.
- Clicking a frame jumps the editor to that call site and shows that frame's locals: `amount=750 quantity=3` in `discount`, `base=750` in `price`, `order` with `id=7 quantity=3 unit_price=250` in `checkout`.
- C++: these are `lab::Order` member functions, so `this` expands to `id_`, `quantity_`, `unit_price_` and `currency_ = "EUR"`. `apply_tax` is a static member and has no `this`.
- Step Out three times climbs back to `stack` with `receipt` still unset. Step Over sets it to 810.

## 3. recursion: deep stacks, conditions, hit counts

- Breakpoint on `return 1;` in `factorial`. The stack shows eight `factorial` frames (n = 1 … 8). Click them to see `n` change from frame to frame.
- Move the breakpoint to `below = factorial(n - 1)` and give it the condition `n == 3`. It stops once, with six `factorial` frames.
- Put a breakpoint in `fibonacci` with hit count `10`. It stops on the 10th call, not the first.
- `is_even` / `is_odd` call each other: a breakpoint in `is_odd` shows the two functions alternating in the stack.
- C++ also has a template recursion `Power<3>::of(4)`. Step Into walks through `Power<3>`, `Power<2>`, `Power<1>`, `Power<0>`, which are distinct frames.

Expect `8! = 40320, fib(10) = 55, 7 even = false/0` (C++ adds `4^3 = 64`).

## 4. loops: conditions and watches

Breakpoint on `sum += square` in `loops`.

- Condition `i == 42`: it stops once, with `square = 1764`.
- Add watches `sum`, `i * 2` and `checkpoints` (Rust/C++) or `checkpoints[saved - 1]` (C). Continue (⌥⌘R) and watch them update at every stop.
- Remove the condition and set hit count `25`: the first stop has `i = 24`.
- Step Over on the `while (countdown > 0)` line: stepping goes back and forth between the condition and the body five times.
- Rust: `evens` is built by `filter` and `map` with block closures. A breakpoint on `let keep = …` stops inside the closure, 20 times, with `Iterator` and `FnMut` library frames below it. Step Into on the `let evens` line goes into `Iterator::filter` instead. C uses a `do … while` loop to find `largest`.

Expect `sum=328350`.

## 5. data: the variable tree

Breakpoint on the `println!` / `printf` at the end of `data`, then expand Locals.

- Structs nested two deep: `rect.origin.x = 1.5`, `rect.size`, and `rect.label = "window"` (a `String`, `std::string` or `char[16]`).
- Enum or union with a payload: `shapes[1]` is a circle with radius 2.5, `shapes[2]` a polygon with three points. Rust shows the variant names. C shows the union `as` and its `kind`.
- `large` has 250 elements. The variable tree pages children 100 at a time, so `more…` appears twice.
- Option and optional: `maybe_found`/`found` is set, `missing` is empty.
- Map: `inventory` with apples 12 and pears 3. Shared pointers: `shared` and `alias` point at the same vector with two strings. Owned box: `boxed`/`owned`.
- C: `list` is a linked list (400 → 300 → 200 → 100); expand `next` repeatedly. `grid` is a 3×4 array, `heap` a pointer to a struct, `greeting` a `const char *`.
- Evaluate Expression (⌥F8): try `rect.size.x * 2`, `fixed[7]` and `large[249]`.

## 6. dispatch: indirect calls

Breakpoint on `area = shape.area()` / `shape->area()` / `shapes[i].ops->area(&shapes[i])`.

- Step Into reaches `Circle::area` on the first pass and `Square::area` on the second: trait object, virtual call, or a function-pointer table in C.
- Step Into on `scale(5)` / `stored(5)` enters the lambda or closure. In C++ it goes through `std::function` first, so Step Out returns from that.
- Step Into on `apply(negate, …)` reaches `negate` through a function pointer.
- `sort_by_key`, `std::sort` and `qsort` call the comparator many times: a breakpoint in the comparator, or in the C function `by_length`, stops on each call from inside the library frames.

## 7. threads: the thread picker

Breakpoint on `contribution = id * 10 + round` in `work`.

- The debugger stops in one worker; the thread picker lists `main` plus the workers (Rust names them `worker-0` … `worker-2`). Picking another thread loads its stack: the others are usually in `sleep` or still at thread start.
- Continue: each worker stops three times (once per `round`), nine stops in total.
- Condition `id == 2`: only the third worker stops.

Expect `threads: total=99`.

## 8. faults: errors and exceptions

- Rust: `validate(-1)` panics inside `catch_unwind`. Set a breakpoint on the `panic!` line; Continue then unwinds back into `faults` and `caught` is set. `parse_quantity("twelve")` returns `Err` through `?`: Step Into shows the early return.
- C++: enable **Debug › C++ Throw** (and/or **C++ Catch**). The first stop is in `__cxa_throw` from `std::stoi`, which throws `std::invalid_argument` for `"twelve"` (caught in `parse_quantity`). Continue: the second stop is `__cxa_throw` with `validate` one frame up. Continue again lands in the `catch` block.
- C: `validate` leaves through `longjmp`, so its frame never returns. Step Over on `longjmp(recovery, value)` is a runaway step: lldb loses the frame and the program runs to the end. Put a breakpoint on the `printf` in `lab_faults` first; Step Over then stops there with `code = -1`.

## 9. heartbeat: Pause, Continue, Stop

`heartbeat` prints `heartbeat N/40` twice a second for 20 seconds. Run it on its own (Program Arguments `heartbeat`) or let the other scenarios finish.

- **Pause** stops inside `sleep`/`nanosleep`/`usleep`. The top frames have no source; frame selection still shows `heartbeat` with the current `beat`.
- **Step Out** a few times (one per system frame) returns to the loop in `heartbeat`. **Continue** resumes and the output keeps coming.
- **Stop (⌘F2)** ends the session part-way through.

## 10. fork: attach to a child process

`fork` forks once. The child runs `child_work` 60 times, twice a second, for 30 seconds, then exits. Program Arguments `fork <seconds>` sets how long the parent waits before it forks (default 10). The output shows both PIDs:

```
fork: parent pid 31548 forks in 10 s
fork: child pid 31550
fork: child total=73810
fork: child 31550 exited with 0
```

lldb debugs one process and does not follow a fork, so the child is reached by attaching to it. Start the program with **Run** (⌘R), not Debug: under Debug, only the parent is debugged and the child runs through its breakpoints. C and C++ need a **Run › Build** first, because Run does not build CMake targets.

Set a breakpoint on `let squared = round * round;` / `int squared = round * round;` in `child_work` first.

**By PID.** Set Program Arguments to `fork 0` and Run. Open **Debug › Attach to Process…**, type `debugger-lab` in the filter, and pick the row whose PID matches `fork: child pid`. Its parent column shows the parent's PID. Attach. The debugger stops in `child_work`, and `round` counts up on each Continue.

**By waiting for it.** Set Program Arguments to `fork` (10 s delay) and Run. While the parent counts down, open **Debug › Attach to Process…**, switch to **Wait for Launch** (the name defaults to the selected target's binary) and Attach. lldb skips processes that already exist, so it catches the child when the parent forks, not the parent itself. If the wait starts before the parent, it catches the parent instead.

- The threads, stack and variables panels work as for a launched program. Step Over and Continue stay in the child; the parent is not stopped.
- **Stop (⌘F2)** detaches: the child keeps running and the parent still prints `exited with 0` at the end.
- Attaching needs macOS developer mode, as debugging does.

## Button bar and menu

The same controls are in the **Debug** menu and in the Debug panel header: Debug, Continue, Step Over, Step Into, Step Out, Pause, Stop. While running, only Pause and Stop are enabled; while stopped, Continue and the three steps. Each scenario above can be driven from either.

## Automated check

Ride's in-app self-test drives scenarios 1, 2, 3, 4, 7, 9 and 10 (and the C++ Throw filter from 8) through the real debugger when it is opened on one language folder of the lab. It presses the Debug shortcuts and menu items, clicks the gutter, fills in the breakpoint dialog, and checks that the editor follows each stop. It needs macOS developer mode. Run it on a fresh copy, one language at a time:

```
cp -R samples/debugger/rust "$TMPDIR/lab-rust"
Ride -ApplePersistenceIgnoreState YES --demo selftest --open "$TMPDIR/lab-rust" --report "$TMPDIR/lab-rust.txt"
```

The steps are named `lab …` (`app/Ride/Debug/SelfTestSteps+DebugLab*.swift`). `--only` runs a subset, one whole scenario at a time, for example `--only "lab stack breakpoint,lab stack frames,lab stack frame locals,lab stack stop"`.
