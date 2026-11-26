# Draft: Odin issue — globals and types not findable by name in LLDB

**Status:** draft, not filed. Verified on `dev-2026-11-nightly:9a69916` on 2026-11-25.
Upstream issues searched 2026-11-25 for "DWARF namespace", "lldb global", "debug info
global variable", and "DW_TAG_namespace": no matches. PR search for "DWARF namespace"
found only #7831 ("Find an `any`'s named type in lldb on DWARF", merged ~2026-10). It
added the `_lldb_types_named` workaround quoted below and, as a stated design decision,
kept the fix in the printer rather than the compiler: "The compiler could emit a DWARF
namespace for each package, but that would rename every type that gdb and the gdb
printer see." It does not fix globals; the issue below addresses that trade-off. Before filing, re-run the repro on the latest nightly. Local repro: `main.odin` in this directory.

Odin's own `base/runtime/odin_debugger.py` already notes the type half of this
(`_lldb_types_named`: "`FindTypes` reads `main::Point` as `Point` in a namespace
`main`, but on DWARF the name is the whole of `main::Point`, with no namespace, so it
finds nothing") and works around it with a per-module type index.

**Impact on squeeze:** CLion hover, watches, and Evaluate show "'platform' has unknown
type" for every Odin global, and the Variables view lists only locals. Workaround until
fixed: the `og` LLDB command (`~/.config/lldb/odin_global.py` in Hector's dotfiles),
typed in CLion's LLDB tab, e.g. `og platform.app_input`. Plain LLDB:
`target variable --regex '^main::platform$'`.

---

## Title

DWARF: package-scoped globals and types are emitted with flat `pkg::name` names and no
`DW_TAG_namespace`, so LLDB (and IDEs built on it) cannot find them by name

## Description

Odin emits a global `counter` in package `main` as a single `DW_TAG_variable` named
`main::counter`, and the type `Point` as `DW_TAG_structure_type` named `main::Point`.
There is no `DW_TAG_namespace` anywhere in the output.

LLDB treats `::` in a lookup name as a scope separator: `main::counter` means
"`counter` inside namespace `main`". With no namespace entry, every by-name lookup
fails, whether written `counter` or `main::counter`:

- `target variable`, `expr`, `type lookup`, and `p` cannot find globals or types.
- Front ends that evaluate expressions through LLDB inherit the failure: CLion (and
  likely VS Code with CodeLLDB) shows "'counter' has unknown type; cast it to its
  declared type to use it" on hover, in watches, and in Evaluate. In a running process
  the expression evaluator finds the bare Mach-O symbol `_main::counter` but no debug
  info for it.

The debug info itself is complete and correct: a regex lookup that matches the whole
flat name finds the variable with its full type and value.

## Environment

- Odin `dev-2026-11-nightly:9a69916`
- macOS 27.0.1, arm64; Apple LLDB from Apple clang 21.0.0 (`clang-2100.3.34.2`)
- `-debug`

## Reproduction

```sh
odin build . -debug -out:repro
```

By-name lookups (no process needed):

```
(lldb) target variable counter
error: can't find global variable 'counter'
(lldb) target variable main::counter
error: can't find global variable 'main::counter'
(lldb) type lookup main::Point
no type was found matching 'main::Point'
(lldb) expr -- main::counter
error: 'main' is not a class, namespace, or enumeration
```

Regex lookup of the flat name works:

```
(lldb) target variable --regex ^main::counter$
(int) main::counter = 0
(lldb) target variable --regex ^main::origin$
(main::Point) main::origin = (x = 0, y = 0)
```

The DWARF (`dwarfdump --name=main::counter repro.dSYM`):

```
DW_TAG_variable
  DW_AT_name      ("main::counter")
  DW_AT_type      ("int")
  DW_AT_external  (true)
  DW_AT_location  (DW_OP_addr 0x100060598)
```

`dwarfdump --debug-info repro.dSYM | grep -c DW_TAG_namespace` prints `0`.

## Expected

`target variable counter` (while stopped in package `main`), `target variable
main::counter`, `expr main::counter`, and `type lookup main::Point` all resolve, as
they do for C++ namespace members. IDE hover and watches show package globals.

## Relation to #7831

#7831 fixed the same root cause for one case, an `any` holding a named type, inside the
lldb printer, and chose that over emitting namespaces because they "would rename every
type that gdb and the gdb printer see." A printer cannot fix this case: hover, watches,
`expr`, and `target variable` resolve names in LLDB itself, before any printer runs, so
globals stay unreachable by name in every LLDB front end.

The rename concern does not apply to LLDB. An experiment: clang's IR for a C++ global
in a namespace, with the compile unit relabelled `DW_LANG_C99` (Odin's language), built
with `clang -c -g` and `dsymutil`:

```cpp
namespace main_pkg { struct Point { int x, y; }; int counter = 42; Point origin = {3, 4}; }
int main() { return main_pkg::counter + main_pkg::origin.x; }
```

```sh
clang++ -g -O0 -S -emit-llvm ns.cpp -o cpp.ll
sed 's/DW_LANG_C_plus_plus[_0-9]*/DW_LANG_C99/' cpp.ll > c99.ll
clang -c -g c99.ll -o c99.o && clang c99.o -o c99 && dsymutil c99
```

```
(lldb) target variable main_pkg::counter
(int) main_pkg::counter = 42
(lldb) target variable main_pkg::origin
(main_pkg::Point) main_pkg::origin = (x = 3, y = 4)
(lldb) type lookup main_pkg::Point
struct Point { int x; int y; }
(lldb) expr -- main_pkg::counter
(int) $0 = 42
```

LLDB honours `DW_TAG_namespace` in a C99 unit and still displays the qualified name
`main_pkg::Point`, so nothing is renamed on the LLDB side and the language attribute
can stay as it is. gdb's behaviour was not tested (no gdb on macOS arm64).

## Suggested fix

Emit one `DW_TAG_namespace` per package (`DW_AT_name ("main")`) per compile unit, and
create package-level variables and types inside it with their unqualified names
(`counter`, `Point`). With the LLVM C API this is `LLVMDIBuilderCreateNameSpace` and
using the result as the scope of the global variable and type entries, instead of the
compile unit or file. Keeping the qualified symbol as `DW_AT_linkage_name` would also
let debuggers tie the Mach-O symbol `_main::counter` to its debug info.

If the gdb rename is a blocker, a narrower option is to emit namespaces only on Darwin
targets. LLDB is the platform debugger there and, as far as we know, gdb does not
support macOS arm64, so no gdb user would see a change. Linux LLDB users would keep the
current behaviour.

Either way, `odin_debugger.py` could then drop the per-module type index from #7831.
Procedures may have the same naming; not checked.
