# Draft: Odin issue — frame pointers on macOS arm64

**Status:** draft, not filed. Verified on `dev-2026-10-nightly:84bc3fc` (also present
in `dev-2026-09-nightly:a2fb372`) on 2026-10-28. Before filing, re-run the repro on the
latest nightly and re-search issues/PRs for "frame pointer" / "frame-pointer".

Related upstream history (checked 2026-10-28):
- PR #2940 (2023, closed unmerged): "add frame pointer attribute to procs in debug
  mode". The author switched their backtrace package to libunwind and closed it, but
  noted frame pointers are expected on arm64 macOS.
- #7748 (2026-10-04, closed as duplicate): proposal for `-no-omit-frame-pointer`
  (freestanding kernel use case). The duplicate target was not linked.
- PR #7809 (merged 2026-10-07) added `frame_address`/`return_address` intrinsics;
  it does not change frame-pointer emission.

Mention #2940 and #7748 in the filed issue. Local repro files: `main.odin`,
`control.c` in this directory.

---

## Title

macOS arm64: generated procedures don't maintain the frame-pointer chain (x29), so
`backtrace()`, frame-pointer profilers, and crash stacks lose all Odin frames

## Description

On macOS arm64, Odin procedures save `x29`/`x30` in their prologue but never set
`x29` to their own frame record. Odin's LLVM IR carries no `"frame-pointer"`
function attribute, so LLVM omits frame pointers. Clang, for the same target, marks
every function `"frame-pointer"="non-leaf"`.

Apple's arm64 ABI requires a valid frame record chain: "The frame pointer register
(x29) must always address a valid frame record" ("Writing ARM64 code for Apple
platforms"). Tools that walk frame pointers therefore skip every Odin frame:

- `backtrace()` from libSystem returns only the innermost frame.
- Profilers that capture callstacks by walking frame pointers (for example Tracy's
  macOS client, which uses `backtrace()`) show allocations and zones with no Odin
  callers. In mixed C/Odin programs, stacks jump from an Odin leaf directly to the
  nearest C frame.
- Other frame-pointer-based stack collection on macOS is likely affected too
  (sampling profilers, crash-time stack capture); we have not tested each.

Unwind tables are correct: Apple's libunwind (`unw_step`) walks the same Odin frames
correctly. Only the frame-pointer chain is missing.

## Environment

- Odin `dev-2026-10-nightly:84bc3fc` (also `dev-2026-09-nightly:a2fb372`)
- macOS 27.0.1, arm64 (Apple M1 Max)
- Apple clang 21.0.0 (control program)
- Happens with `-debug` (`-o:none`) and `-o:speed`

## Reproduction

`main.odin`: three `optimization_mode="none"` procedures; the innermost one walks
the stack with `backtrace()` and with Apple libunwind.

```sh
odin build . -debug -out:repro
./repro
```

Actual:

```
backtrace() returned 1 frames (expected: level_3, level_2, level_1, main::main, main, start):
0   repro   0x0000000100251dd0 main::level_3 + 112
libunwind (unw_step, starts at the caller) returned 4 frames:
0   repro   0x0000000100252000 main::level_2 + 28
1   repro   0x0000000100252028 main::level_1 + 28
2   repro   0x0000000100252050 main::main + 28
3   repro   0x000000010024e418 main + 220
```

Same output with `-o:speed`.

C control (`control.c`), same call chain:

```sh
clang -O0 -g control.c -o control && ./control
```

```
backtrace() returned 5 frames:
0   control  level_3 + 48
1   control  level_2 + 12
2   control  level_1 + 12
3   control  main + 28
4   dyld     start + 6688
```

Prologues (`otool -tV -p '_main::level_2' repro`):

```
sub  sp, sp, #0x20
stp  x29, x30, [sp, #0x10]     ; saves the caller's x29 ...
str  x0, [sp]                  ; ... but never `add x29, sp, #0x10`
```

Clang (`otool -tV -p _level_2 control`):

```
stp  x29, x30, [sp, #-0x10]!
mov  x29, sp                   ; x29 now addresses this frame record
```

IR attribute check:

```sh
mkdir ir && odin build . -debug -build-mode:llvm-ir -out:ir
grep -c '"frame-pointer"' ir/*.ll        # 0 in every module
clang -O0 -S -emit-llvm control.c -o - | grep -o '"frame-pointer"="[a-z-]*"' | sort -u
# "frame-pointer"="non-leaf"
```

## Expected

On Darwin targets, Odin procedures keep a valid frame record chain, matching the
platform ABI and clang's default, so `backtrace()` returns `level_3, level_2,
level_1, main::main, main, start`.

## Suggested fix

Add the `"frame-pointer"` function attribute when creating procedures: `"non-leaf"`
on Darwin targets by default (clang's default there), and optionally an opt-in flag
such as `-no-omit-frame-pointer` (`"all"`) for other targets (#7748's use case).
The attribute plumbing already exists next to the other procedure attributes in
`src/llvm_backend_proc.cpp` (`lb_add_attribute_to_proc_with_string`). Cost on arm64
is one instruction per non-leaf prologue and one register (`x29`), which the ABI
already reserves.
