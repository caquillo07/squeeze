# Sprint: Compression Pipeline

**Started:** [Date]
**Status:** Not Started

## Goal
Compress a video on iOS using VideoToolbox through core, with preset targets. The full loop: pick video in gallery -> configure compression -> encode -> save/share.

## Context
This is the core product feature — the reason Squeeze exists. VideoToolbox is a pure C API, so the encoding pipeline lives in core (compress_vt.odin or vt_shim.c). Swift handles only the UI flow and PhotoKit asset access.

### Sequencing notes (updated 2026-06-19)
- **Images come first.** Per the v1 roadmap, image compress + HEIC↔JPEG convert ship in alpha; this video sprint is part of the same alpha push but image is the simpler pipeline to land first. The detail view (its own sprint) is now the foundation both hang off — the "detail view with metadata card" that used to live in this sprint's Phase 2 has moved there.
- **Uses the core job system** (see architecture.md): `squeeze_submit_compress` returns a `Job_Id`; the UI polls per frame via `CADisplayLink`. No callbacks up into the UI.
- **Don't use `AVAssetExportSession`** (Obj-C) — it would strand the logic in Swift. Use VideoToolbox (C) so compression policy stays in core.

---

## Phases

### Phase 1 — VideoToolbox from Odin/C
- [ ] Prototype: call VTCompressionSessionCreate from Odin (foreign) or C shim
- [ ] Encode a test video buffer to H.264
- [ ] Decide: Odin foreign bindings vs C shim (based on API cleanliness)
- [ ] Implement compress_vt (whichever approach won)
- [ ] Wire up the compress.odin dispatch interface

### Phase 2 — iOS Compression Flow
- [ ] (detail view + metadata card moved to the Media Detail View sprint — depends on it)
- [ ] Compress config screen with preset grid (target sizes)
- [ ] Size estimation (target size -> bitrate calculation)
- [ ] Progress view with percentage
- [ ] Done view with before/after comparison
- [ ] Share + Save to camera roll

### Phase 3 — Desktop Compression (ffmpeg backend)
- [ ] Implement compress_ffmpeg.odin
- [ ] Same dispatch interface, different backend
- [ ] Encode a test file via desktop app

---

## Learnings
- (captured as we go)
