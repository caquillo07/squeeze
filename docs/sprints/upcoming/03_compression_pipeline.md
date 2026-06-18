# Sprint: Compression Pipeline

**Started:** [Date]
**Status:** Not Started

## Goal
Compress a video on iOS using VideoToolbox through core, with preset targets (WhatsApp, Discord, Email). The full loop: pick video in gallery -> configure compression -> encode -> save/share.

## Context
This is the core product feature — the reason Squeeze exists. VideoToolbox is a pure C API, so the encoding pipeline lives in core (compress_vt.odin or vt_shim.c). Swift handles only the UI flow and PhotoKit asset access.

---

## Phases

### Phase 1 — VideoToolbox from Odin/C
- [ ] Prototype: call VTCompressionSessionCreate from Odin (foreign) or C shim
- [ ] Encode a test video buffer to H.264
- [ ] Decide: Odin foreign bindings vs C shim (based on API cleanliness)
- [ ] Implement compress_vt (whichever approach won)
- [ ] Wire up the compress.odin dispatch interface

### Phase 2 — iOS Compression Flow
- [ ] Detail view with metadata card (file size, dimensions, codec, duration)
- [ ] Compress config screen with preset grid (WhatsApp/Discord/Email)
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
