# Squeeze — Project Instructions

## Read First

- **Coding style guide:** `docs/references/coding_style.md` — read it, follow it, no exceptions.
- **Active sprint:** `todo.md` — current work lives here.
- **Sprint template:** `docs/sprints/_template.md` — copy this to start a new sprint.

## Core Principles

- Simple, clear, fast. Not mutually exclusive.
- Respect memory and CPU. Battery is sacred. Crashes are unacceptable.
- No singletons. No OOP hierarchies. No premature abstraction.
- Arenas for C memory. Context allocators for Odin.
- YAGNI. Build what's needed, nothing more.

## Languages (by preference)

- **Odin** — primary language, core logic, desktop app
- **C** — shims wrapping complex C APIs (ffmpeg, VideoToolbox if needed)

## Monorepo Structure

```
squeeze/
├── core/        — shared C + Odin logic
│   └── vd/      — backend-neutral C library; unity build + owned tests
├── desktop/     — Odin + SDL3 desktop app
├── ext/         — shared vendored dependencies (SDL3, ffmpeg, etc.)
├── docs/
│   ├── references/  — style guide, architecture, vision
│   └── sprints/     — sprint templates and archives
├── justfile     — build commands
└── todo.md      — active sprint
```

## Build System

- `justfile` wraps CMake for VD and `odin build` for desktop.
- CMake presets are shared by terminal and CLion; Debug/Release use separate directories.
- Dependencies build explicitly; normal project builds never rebuild FFmpeg.
- Current supported target: macOS arm64. Linux support is planned, not verified.

## Current Scope

Desktop/core only. The iOS app and tooling were removed to avoid maintaining an
inactive target; source remains in Git history. iOS plans live in
`docs/sprints/deferred/` and must not be treated as active work.

## Sprint System

- Active sprint in `todo.md`, upcoming in `docs/sprints/upcoming/`.
- When starting a sprint, copy from upcoming to todo.md.
