# Squeeze — Progress Tracker

## Completed Sprints

(none yet — this is a fresh repo)

## Prior Art (from predecessor projects)

### MediaToolKit (iOS app)
- Gallery with smooth scrolling, prefetch pre-warming, PHCachingImageManager
- File size + duration badges on thumbnails
- Photos-style ordering (oldest top, newest bottom, launch at bottom)
- UICollectionView via UIViewControllerRepresentable (SwiftUI LazyVGrid has no prefetch API)
- Key learnings captured in MediaToolKit's sprint 1

### vdbg_player (Odin desktop app)
- Working C shim (vd.c/h) wrapping ffmpeg decode/format detection
- SDL3 GPU-accelerated rendering with compiled shaders
- Incremental migration pattern from C shim to native Odin

### vdb (Odin prototype)
- Proof of concept for Odin + ffmpeg + SDL3 stack
- Validated the C shim approach