# Squeeze — Project Instructions

## Read First

- **Coding style guide:** `docs/references/coding_style.md` — read it, follow it, no exceptions.
- **Active sprint:** `todo.md` — current work lives here.
- **Sprint template:** `docs/sprints/_template.md` — copy this to start a new sprint.

## Core Principles

- Simple, clear, fast. Not mutually exclusive.
- Respect memory and CPU. Battery is sacred. Crashes are unacceptable.
- No singletons. No OOP hierarchies. No premature abstraction.
- Arenas for C memory. ARC for Swift (iOS shell only). Context allocators for Odin.
- YAGNI. Build what's needed, nothing more.

## Languages (by preference)

- **Odin** — primary language, core logic, desktop app
- **C** — shims wrapping complex C APIs (ffmpeg, VideoToolbox if needed)
- **Swift** — iOS shell only (UIKit, PhotoKit, StoreKit, app lifecycle)

## Monorepo Structure

```
squeeze/
├── core/        — portable C + Odin library (zero platform imports)
│   └── shim/    — C shims for ffmpeg, VideoToolbox, etc.
├── desktop/     — Odin + SDL3 desktop app
├── ios/         — Swift UIKit iOS app (thin shell over core)
├── ext/         — shared vendored dependencies (SDL3, ffmpeg, etc.)
├── docs/
│   ├── references/  — style guide, architecture, vision
│   └── sprints/     — sprint templates and archives
├── justfile     — build commands
└── todo.md      — active sprint
```

## Build System

- `justfile` wraps `odin build` and `cc`/`clang` for core and desktop.
- iOS builds through Xcode. Core C files added directly to the Xcode project.
- arm64 only (no x86).

## Sprint System

- Active sprint in `todo.md`, upcoming in `docs/sprints/upcoming/`.
- When starting a sprint, copy from upcoming to todo.md.
