# Coding Style Guide — Squeeze

This is law. Read it before writing code.

---

## Philosophy

We follow the Handmade Hero approach. We are engineers, not framework consumers. We respect the user and the device. Simple, clear, and fast are our goals — and they are not mutually exclusive.

YAGNI is our friend. We do not add complexity to feel smart. We do not subscribe to "best practices" cargo-culted from social media. We do real engineering.

**We respect memory and CPU above all else.** This is a media tool on a user's device. Battery life matters. Smooth frame delivery matters. Crashes are unacceptable. Every allocation, every cycle, every watt — we earn the right to use it.

We will not compromise on user experience and product quality.

---

## Compression-Oriented Programming

1. Write the concrete, specific code first. Solve the actual problem.
2. When you see the same pattern **three or more times**, then compress it into a shared function or abstraction.
3. Never abstract preemptively. Two instances of similar code is not a pattern — it's a coincidence.
4. If you can't name the abstraction clearly, you don't understand it yet. Keep the concrete code.

---

## Simplicity

- Straight-line control flow. Top to bottom. No callback spaghetti.
- No design patterns for the sake of design patterns. No factories, no visitors, no strategy pattern unless the problem genuinely demands it (it almost never does).
- Simple version first. Always. Get it working, then decide if it needs to be fancier (it usually doesn't).
- Three similar lines of code is better than a premature abstraction.
- If a junior engineer can't read it in 30 seconds, it's too clever.

---

## No Magic

We write imperative code. Every operation is explicit. If you have to guess what a line does, it's wrong.

- **Explicit returns.** Always write `return`. No implicit returns, no trailing expressions that silently become the return value. The reader should never have to wonder "wait, is this returning?"
- **No property wrappers that hide control flow.** If a `@Something` annotation changes when or how code executes, inline the behavior or use a plain function call.
- **No operator overloading for cleverness.** Operators should do what they look like they do. `+` adds things. `<<` shifts bits. Don't make `<<` mean "append to stream" or `~` mean "approximately matches."
- **No implicit conversions.** If a type changes, write the conversion. The compiler might do it for you — write it anyway.
- **No builder patterns, no fluent chaining, no DSLs.** Call functions. Pass arguments. Assign results to variables with names. Chained calls hide intermediate state and make debugging miserable.
- **Spell it out.** More keystrokes is fine. More lines is fine. Code that reads like a sequence of clear steps beats code that reads like a riddle. We're not golfing.

---

## Respect the Machine

- No wasted copies. If you're copying data, ask yourself why.
- No unnecessary allocations. Reuse buffers. Pre-allocate when the size is known.
- No work in hot loops that doesn't need to be there. Hoist invariants out.
- Know your data sizes. Know your cache lines. Think about what the CPU is actually doing.
- Profile before optimizing, but write code that doesn't need optimizing in the first place.
- **Battery is sacred.** Unnecessary CPU work drains battery. Sleep when idle. Don't poll when you can wait. Don't compute what you can cache.
- **Smooth is non-negotiable.** Frame drops, hitches, UI stalls — these are bugs, not "performance issues."

---

## Performance

Last priority — because the rules above give you 80% for free. The remaining 20% is profiler-guided:

1. Measure first. Gut feelings about performance are wrong.
2. Find the actual bottleneck with Instruments / profiler.
3. Fix that specific thing. Don't scatter optimizations everywhere.
4. Measure again to confirm the fix worked.

---

## Memory Rules

### Odin (Primary)

- Use context allocators — the arena pattern maps naturally to Odin's allocator system.
- `defer` for cleanup when needed, but prefer arena resets over individual frees.
- Temp allocator for scratch work.
- Prefer `#soa` arrays when the access pattern benefits from it.
- Keep it simple — Odin is designed for clarity, lean into that.

### C (Shims — Static Allocation + Arenas)

- **No scattered `malloc`/`free`.** All memory is allocated statically up front or through arenas.
- Arenas are the primary allocation strategy. Allocate a block at startup, sub-allocate from it. Reset or rewind — never free individual objects.
- Predictable memory is the goal. At any point in the program, you should be able to answer: "How much memory is this using?" without guessing.
- Temporary/scratch arenas for per-frame or per-operation work — allocate forward, reset at the end.
- Permanent arenas for long-lived data that persists for the application lifetime.
- **No heap fragmentation.** Arenas prevent it by design.
- **Crashes are unacceptable.** Null pointer dereferences, use-after-free, double-free, buffer overruns — these don't happen when memory is statically bounded and arena-managed. That's the whole point.
- If you're reaching for `malloc`, stop and think about which arena this should come from.

### Swift (iOS Shell Only — ARC + Manual Pools)

- ARC handles the common case. Don't fight it.
- Use `@autoreleasepool` blocks in tight loops and batch processing to keep memory pressure under control.
- Never allocate in a hot path if you can allocate once and reuse.
- Watch for retain cycles in closures — use `[weak self]` or `[unowned self]` when capturing `self` in escaping closures.
- Prefer value types (structs). They live on the stack when possible — no heap allocation, no refcounting overhead.
- When in doubt, use Instruments Allocations to check.

---

## Crash Prevention

Crashes are **never acceptable** in shipped code. Period.

- Validate all external input at system boundaries. Trust nothing from outside.
- Internal code paths should be structured so invalid states are unrepresentable.
- Use arenas and static allocation to eliminate memory-related crashes entirely.
- In Swift: no force-unwraps (`!`) outside of tests and `IBOutlet`s. Handle every optional.
- In C: bounds-check array access in debug builds. Use arena limits to catch overflows.
- In Odin: bounds checking is on by default. Leave it on in debug. Use `#no_bounds_check` only in measured hot paths.
- Prefer returning error values over `assert`/`abort` in release builds.
- If something can fail, handle the failure. If something "can't" fail, add a comment explaining why — and handle it anyway.

---

## Data-Oriented Thinking

- Structs are data. Functions transform data. That's it.
- No OOP hierarchies. No class inheritance trees. No "AbstractMediaProcessorFactory".
- Arrays of structs over linked lists. Contiguous memory wins.
- Prefer value types (structs) over reference types (classes) in Swift.
- No singletons. Pass dependencies explicitly. If everything needs it, thread it through.
- Think about how the data flows through the system, not about object relationships.

---

## Architecture Rules

- **No singletons.** Global mutable state is a bug waiting to happen. Pass what you need.
- **Prefer value types.** Odin structs, C structs, Swift structs. Classes only when you genuinely need reference semantics (iOS UIKit).
- **Flat over nested.** Shallow module trees. If your folder structure is 5 levels deep, something went wrong.
- **Delete dead code.** Don't comment it out. Git remembers.

---

## The Casey Test

Before submitting code, ask: "Would Casey Muratori fire me for this?"

- Is there unnecessary indirection?
- Am I doing work the machine doesn't need to do?
- Did I add complexity that doesn't serve the user?
- Is this code honest about what it's actually doing?
- Am I wasting the user's battery?

If the answer to any of these is yes, fix it.

---

## Code Review Checklist

When reviewing (matches `/review` command):

- [ ] Does it do what it claims?
- [ ] Is there unnecessary complexity?
- [ ] Are there unnecessary allocations or copies?
- [ ] Is memory usage predictable and bounded?
- [ ] Is the control flow obvious?
- [ ] Are error cases handled without over-engineering?
- [ ] Would a simpler approach work just as well?
- [ ] Is there dead code or commented-out code to remove?
- [ ] Does it respect the device (memory, CPU, battery)?
- [ ] Can this crash? If so, fix it.
- [ ] Are all returns explicit?

---

## Language-Specific

### Odin

- Follow Odin idioms: context system, `defer`, multiple return values.
- Use context allocators — arenas map directly to Odin's allocator model.
- Prefer `#soa` arrays when the access pattern benefits from it.
- Explicit returns always. `return result` not a trailing expression.
- Keep it simple — Odin is designed for clarity, lean into that.

### C

- C-style. Plain structs and functions.
- No class hierarchies. No virtual dispatch.
- **All memory through arenas.** No `malloc`/`free` pairs scattered through the code.
- Static allocation at startup. Sub-allocate from arenas.
- Use `static` for file-scoped functions and variables.
- Prefer stack allocation over arena allocation when lifetimes are lexical.
- Bounds-check in debug builds. Arena limits catch overflows.

### Swift (iOS shell only)

- Prefer `struct` over `class`.
- Use `enum` with associated values over class hierarchies.
- Avoid `Any` and `AnyObject` — be explicit about types.
- Use `let` by default. `var` only when mutation is required.
- No force-unwraps (`!`) outside of tests and `IBOutlet`s. Handle optionals properly.
- Keep closures short. If a closure is more than ~10 lines, extract it to a function.
- `guard` for early exits. No deep nesting.
- Always use explicit `self` when referencing class members inside methods.
- Always write explicit `return` statements. No implicit returns.
- Use `@autoreleasepool` in loops that create many temporary objects.

---

## Exceptions

Prototype, spike, and POC branches are exempt from this guide. Move fast, break things, throw it away. But **never** merge prototype-quality code into main.