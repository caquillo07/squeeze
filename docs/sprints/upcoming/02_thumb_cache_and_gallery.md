# Sprint: Thumb Cache & Gallery

**Started:** [Date]
**Status:** Not Started

## Goal
Replace NSCache in the iOS gallery with core's C thumb cache. Thumbnails are decoded, cached, and served from core. Swift just displays the pixel data.

## Context
The iOS app currently uses NSCache for thumbnail caching (proven in MediaToolKit sprint 1). This sprint replaces it with a C LRU cache in core/ that both iOS and desktop can use. This is the first real "shared code" payoff of the monorepo.

---

## Phases

### Phase 1 — C Thumb Cache Implementation
- [ ] Implement LRU eviction in thumb_cache.c
- [ ] Fixed capacity (max entries) + explicit memory budget (max bytes)
- [ ] Insert: key (string) + pixel data (RGBA buffer) + dimensions
- [ ] Lookup: key -> pixel pointer + dimensions (or null on miss)
- [ ] Memory tracking: each entry knows its byte size, total tracked
- [ ] Test: standalone C program that inserts/evicts/looks up

### Phase 2 — iOS Integration
- [ ] Remove NSCache usage from GalleryViewController
- [ ] Create ThumbCache instance in Swift via bridging header
- [ ] Wire PHImageManager results into thumb_cache_insert
- [ ] Wire cellForItemAt to thumb_cache_get
- [ ] Verify scrolling performance matches or beats NSCache version
- [ ] Profile with Instruments Allocations — memory budget respected

### Phase 3 — Desktop Integration
- [ ] Wire SDL3 texture creation from thumb_cache pixel data
- [ ] Verify desktop app can display cached thumbnails

---

## Learnings
- (captured as we go)
