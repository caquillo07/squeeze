# Sprint: Odin Video Player

**Started:** [Date]
**Status:** Not Started

## Goal
A working video player in the desktop Odin app that matches the C++ video_editor's functionality: video + audio decoding, threaded pipeline, A/V sync, and HUD overlay. Then add the JS scripting overlay system.

## Context
The C++ video_editor (at /Users/hector/code/video_editor) is a video player built as a learning project following ffmpeg tutorials. It has video/audio decoding, threaded demux/decode, A/V sync (audio master clock), HUD, and a QuickJS scriptable overlay system with a software rasterizer. We're porting all of this to Odin in the Squeeze desktop app, using the C shim (core/shim/vd.c) for ffmpeg calls.

## What Exists (C++ video_editor)
- FFmpeg demux + decode (video + audio)
- swscale YUV→RGBA conversion
- Audio: swresample → float32 stereo 48kHz → SDL3 audio stream
- Threaded pipeline: demux thread, video decode thread, audio callback on SDL thread
- Ring buffer packet queues (power-of-2, mutex/condvar)
- Picture queue (ring buffer of decoded frames)
- A/V sync: audio clock as master, threshold-based video correction
- HUD overlay: FPS, frame info, PTS/DTS, queue fill levels
- QuickJS scriptable overlays (demo.js per frame)
- Software 2D rasterizer (alpha-blended fillRect, strokeRect, fillCircle, gradients, text, rounded rects)

## What's Missing (from tracker.md)
- A/V sync was listed as "NEXT" (Tutorial 05) — partially implemented but not finished
- Seeking (Tutorial 07)
- Frame dropping when video falls behind audio

---

## Phases

### Phase 1 — C Shim: Full FFmpeg Interface
- [ ] Expand vd.c/vd.h to expose: format open/close, stream info, codec open/close
- [ ] Expose packet read (av_read_frame), packet alloc/free/unref
- [ ] Expose decode send/receive (avcodec_send_packet, avcodec_receive_frame)
- [ ] Expose swscale context create/convert/free
- [ ] Expose swresample context create/convert/free
- [ ] Expose av_q2d, time_base access, PTS helpers
- [ ] Verify shim compiles and links into desktop app

### Phase 2 — Basic Video Playback
- [ ] Open video file from command line arg
- [ ] Demux + decode video frames through C shim
- [ ] swscale to RGBA, upload to SDL texture
- [ ] Frame timing based on stream FPS
- [ ] Playback controls: pause/resume, quit

### Phase 3 — Audio Playback
- [ ] Find audio stream, open audio codec via C shim
- [ ] SDL3 audio stream with callback
- [ ] swresample to float32 stereo 48kHz
- [ ] Packet queue (ring buffer, power-of-2, mutex/condvar)
- [ ] Audio decode in callback, push to SDL

### Phase 4 — Threaded Pipeline
- [ ] Demux thread: reads packets, routes to audio/video queues
- [ ] Video decode thread: pulls from video queue, pushes to picture queue
- [ ] Picture queue (ring buffer of decoded frames)
- [ ] Clean shutdown: quit flags, signal conditions, wait threads, destroy order

### Phase 5 — A/V Sync
- [ ] Audio clock: track PTS from decoded audio frames
- [ ] Video pacing: compare video PTS to audio clock
- [ ] Frame dropping when video falls behind
- [ ] Threshold-based correction (sync tolerance)

### Phase 6 — HUD Overlay
- [ ] FPS counter, frame time
- [ ] Current frame PTS/DTS, keyframe indicator
- [ ] Queue fill levels (packet queues, picture queue)
- [ ] Toggle with key binding

### Phase 7 — JS Scripting Overlay
- [ ] Integrate QuickJS (vendored in ext/ or via C shim)
- [ ] JS API: fillRect, strokeRect, fillCircle, gradients, text, rounded rects
- [ ] Software rasterizer: alpha-blended primitives onto frame pixels
- [ ] Load and execute script per frame
- [ ] Performance stats in HUD

---

## Architecture Notes
- All ffmpeg calls go through core/shim/vd.c — Odin never links ffmpeg directly
- Ring buffers use power-of-2 sizes for fast modulo (idx & (size-1))
- Audio callback runs on SDL thread — no allocations, no logging in hot path
- Audio clock accessed cross-thread via atomics (relaxed ordering)
- RGBA textures for effects/compositing flexibility

## Key References
- /Users/hector/code/video_editor/src/main.cpp — full C++ implementation
- /Users/hector/code/video_editor/notes/vdb_learnings.md — gotchas and tips
- /Users/hector/code/video_editor/notes/avpacket_ownership.md — packet ownership rules
- /Users/hector/code/video_editor/notes/audio_implementation_todos.md — audio implementation details

---

## Learnings
- (captured as we go)

---

## Completion Checklist

Before archiving this sprint:
- [ ] All phases marked complete
- [ ] progress_tracker.md updated with summary + learnings
- [ ] Archive: `mv todo.md docs/sprints/completed/YYYY-MM_odin_video_player.md`
