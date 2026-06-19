# Sprint: Odin Thumb Cache

**Started:** [Date]
**Status:** Not Started

## Goal
Replace NSCache in the iOS gallery with an Odin-implemented LRU thumb cache in core/. Thumbnails cached and served from shared Odin code. Swift just displays the pixel data.

## Context
The iOS app currently uses NSCache for thumbnail caching (proven in MediaToolKit sprint 1). This sprint replaces it with an Odin LRU cache in core/ that both iOS and desktop can use — the first real "shared code" payoff of the monorepo. The cache exports C-ABI functions via `@(export)`, accessed from Swift through the bridging header (same pattern as squeeze_version/squeeze_add).

---

## Phases

### Phase 1 — Odin Thumb Cache Implementation
- [ ] Implement LRU eviction in core/ (Odin, exported as C ABI)
- [ ] Fixed capacity (max entries) + explicit memory budget (max bytes)
- [ ] API: init, insert (key + RGBA pixels + dimensions), get (key → pixel pointer + dimensions or null)
- [ ] Memory tracking: each entry knows its byte size, total tracked
- [ ] Arena-backed allocation (no malloc/free per entry)
- [ ] Test: call from desktop app to verify insert/get/evict cycle

### Phase 2 — iOS Integration
- [ ] Add thumb cache functions to bridging header
- [ ] Remove NSCache usage from GalleryViewController
- [ ] Wire PHImageManager results into thumb_cache_insert
- [ ] Wire cellForItemAt to thumb_cache_get
- [ ] Verify scrolling performance matches or beats NSCache version
- [ ] Profile with Instruments Allocations — memory budget respected

### Phase 3 — Desktop Integration
- [ ] Wire SDL3 texture creation from thumb cache pixel data
- [ ] Verify desktop app can display cached thumbnails

---

## Learnings
- (captured as we go)
