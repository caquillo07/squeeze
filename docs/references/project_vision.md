# Squeeze — Project Vision

## The Dream

Modernize media tooling for everyone.

The app market is segmented into two extremes. Easy-to-use tools are too simplistic for power users. Professional tools are too intimidating for everyday users. The handful that play in the middle are overpriced or have shady business models.

Squeeze sits in the gap: powerful enough for pros, approachable enough for your mom.

## Current Focus

Desktop/core only. The inactive iOS app and tooling were removed on 2026-09-30 to
avoid maintaining a target we are not working on. The mobile product vision below
is deferred, not an existing app or an active delivery plan.

## What Is Squeeze

A media toolkit intended to run across platforms:

- **Squeeze for iOS (deferred)** — the Photos app Apple should have shipped. Gallery-first navigation, file sizes on every thumbnail, contextual actions (compress, convert, resize, strip metadata). UIKit shell over a portable core.
- **Squeeze for Desktop** — a video debugging and processing tool. Think VLC meets ffprobe, but friendlier. Odin + SDL3, custom UI, same portable core.

The desktop app uses `core/`; future frontends can share its portable policy and
backend-neutral APIs. Thumbnail caching, probing, compression, and metadata
extraction are planned features, not implemented library capabilities yet.

## Philosophy

- Gallery-first, not tool-first. You see your media, then act on it.
- No ads, ever. One-time purchase for Pro.
- Metadata preserved by default. Everyone else gets this wrong.
- Hardware-accelerated encoding. VideoToolbox on Apple, ffmpeg on everything else.
- Offline-only. Your media never leaves your device.

## The Squeeze Name

"Easy peasy, lemon squeezy" — that's the UX goal.

Squeeze = compressing video into something smaller. The logo is a lemon/lime. The name is short, memorable, and works as a verb ("just squeeze it and send").

## Deferred Product: iOS App

### Navigation: Browse -> Detail -> Action

You open the app, you see your camera roll. Tap any item, see its details and available actions. Tools grow, navigation stays the same.

**v1:** video selected -> Compress
**v1.1:** video selected -> Compress, Convert
**v1.2:** photo selected -> Convert, Resize, Strip Metadata
**v1.3:** video selected -> Compress, Trim, Convert, Extract Audio, Strip Metadata

### Why This Beats the Competition

Nobody owns the intersection of "clean gallery that surfaces useful info" and "contextual media actions":

- **Gallery apps** (HashPhotos) — great at browsing, tools are afterthoughts
- **Single-purpose tools** (Metapho, compressor apps) — each does one thing, need 5 apps for 5 operations
- **Swiss army knife tools** (Media Converter) — tool-first UX, pick action then pick file — backwards

### Monetization

- **Free:** 3 compressions/day, presets only, full gallery + metadata viewing
- **Pro ($4.99 one-time):** unlimited compressions, custom mode, batch, all future tools
- No ads, no subscriptions

## Product: Desktop App

The desktop app (formerly "vdbg") started as a video debugger for professionals but is evolving into a general-purpose media tool with powerful escape hatches — like VLC and MPV, but built for people who also need to inspect and process media.

- Probe/inspect any media file (codecs, streams, metadata, frame info)
- Playback with frame-level controls
- Compression and conversion
- Extensible with the same action model as iOS

## Technical Strategy

### Languages by preference

1. **Odin** — primary. Core logic, desktop app, anywhere we can.
2. **C** — shims wrapping complex APIs (ffmpeg). We're not afraid of C.
3. **Swift (deferred)** — would be used only for a future iOS shell.

### Why Odin over Swift for core

- Odin is fun. Swift is not (for this developer).
- Odin compiles to native code with simple, predictable behavior.
- Context allocators map perfectly to arena-based memory management.
- Code written in Odin works on every platform. Code written in Swift works on Apple.
- Solo dev productivity matters — working in a language you enjoy is a force multiplier.

### The C Shim Pattern

ffmpeg has a gnarly API with deeply nested structs and macros. Instead of mirroring all of that in Odin:

1. Write a thin C file (~200-400 lines) that includes the ffmpeg headers
2. Expose a flat API of plain functions with simple types
3. Odin calls ~20 clean function signatures instead of wrestling with ffmpeg internals

Proven in `vdbg_player`'s `vd.c/h`.

### Compile-Time Backends

VD selects its backend inside the C unity build. Odin imports the public API and
links one `libvd.a`; FFmpeg stays private. Native backends and compression APIs
are future work. See `vd_backend.md` for the current boundary.

## Future Roadmap

### Media tools (each is a new action)
- Convert (HEIC -> JPG, MOV -> MP4, etc.)
- Resize (exact dimensions for uploads)
- Extract Audio (video -> audio file)
- Strip Metadata (GPS, EXIF — privacy feature)
- Trim (time-level and frame-level)
- Make GIF (from video clip)

### Platform
- macOS app (same core, new Swift shell or desktop app covers it)
- Linux + Windows desktop (core + Odin/SDL3, just works)
- Batch processing
- Share sheet extension (compress from Photos directly)

### Smart features (later, much later)
- Content-aware compression presets
- Natural language targets ("make this small enough to text")
