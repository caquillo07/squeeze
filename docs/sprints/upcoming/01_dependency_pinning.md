# Sprint: Dependency and Toolchain Pinning

**Started:** [Date]
**Status:** Not Started

## Goal
Every vendored dependency and required tool has a recorded, verified version, and
builds fail loudly on a toolchain mismatch.

## Context
FFmpeg 9.0.2 and SDL3 3.4.18 are vendored with recorded archive checksums, but
neither archive's hash or signature has been verified against upstream (the SDL3
`.sig` is kept in `tmp/`; its signing keys could not be fetched).
SDL_gpu_shadercross and SPIRV-Cross have no recorded version, commit, or checksum.
The Odin compiler is not pinned, even though the SDL bindings are a snapshot of a
specific nightly (`9a69916`); `just check-sdl-bindings` already checks that the
bindings and SDL3 declare the same version. Toolchain requirements (clang/SDK, GNU Make, CMake)
are documented but not checked, so Xcode or tool updates can silently change builds.

---

## Phases

### Phase 1 — Verify Existing Imports
- [ ] Check FFmpeg 9.0.2 archive SHA-256 against upstream's published hash/signature
- [ ] Verify the SDL3 3.4.18 archive signature (import keys `1528635D…7763BE6`,
      `09001043…4B61D39B`) or its SHA-256 against upstream's published release
- [ ] Record verification result (date, method) in each `ext/*.README.md`

### Phase 2 — Record Unpinned Dependencies
- [ ] Identify the vendored SDL_gpu_shadercross version/commit and its source
- [ ] Identify the vendored SPIRV-Cross version/commit and its source
- [ ] Record version, upstream URL, checksum or commit, license, and local modifications

### Phase 3 — Pin and Check the Toolchain
- [ ] Record the required Odin compiler version alongside the bindings snapshot
- [ ] `justfile` fails on an Odin version mismatch with a clear message
- [ ] Decide which of clang/SDK, GNU Make, and CMake versions to check vs. only record
- [ ] Verify checks fail correctly with a deliberately wrong version

### Phase 4 — Update Procedure
- [ ] Document one dependency-update checklist under `docs/references/`:
      import, verify, record, rebuild Debug/Release, run C and Odin smoke tests

---

## Current Status

**Completed:**
- (none yet)

**In Progress:**
- (starting)

**Blocked:**
- Upstream verification requires network access

---

## Learnings
- (captured as we go)

---

## Completion Checklist

Before archiving this sprint:
- [ ] All phases marked complete
- [ ] docs/references/ guides written for major features
- [ ] progress_tracker.md updated with summary + learnings
- [ ] Archive: `mv todo.md docs/sprints/completed/YYYY-MM_name.md`
