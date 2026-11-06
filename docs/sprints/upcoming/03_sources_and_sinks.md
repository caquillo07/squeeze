# Sprint: Byte Sources and Frame Sinks

**Started:** [Date]
**Status:** Not Started — idea capture, depends on decode existing (`02_odin_video_player.md`)

## Goal
Decode reads bytes through a backend-neutral source and writes frames to a selectable
sink, so Squeeze can play remote files over SSH and run headless.

## Context
Inspired by mpv's output modes (`--vo=kitty`, `--vo=tct`, `--vo=image`, `--vo=null`).
Two use cases:
- Play media on a remote machine (Linux workstation, VM) from the Mac, with no
  local copy.
- Run and validate Squeeze on Linux over SSH, without a window.

FFmpeg is one backend, not *the* backend. OS backends (AVFoundation, Media
Foundation, …) will follow, so neither sources nor sinks may depend on FFmpeg
types.

---

## Byte Sources

Decode locally; move compressed bytes, never decoded pixels. Raw 1080p30 yuv420 is
~750 Mbps; the test clip is ~13 Mbps compressed.

```
transport (local file | ssh sftp | ssh squeeze serve)
        │  read(offset, len), size
        ▼
   vd source  ── defined in vd.h, backend-neutral
        │
        ▼
backend (ffmpeg | avfoundation | mf | …) → frames → sink
```

Every backend can read through a caller-supplied source. Verify each one by
prototype before relying on it:

| Backend            | Custom-source mechanism                                       |
|--------------------|---------------------------------------------------------------|
| FFmpeg             | `AVIOContext` with read/seek callbacks                        |
| AVFoundation       | `AVAssetResourceLoaderDelegate` (custom URL scheme, byte-range requests) |
| Media Foundation   | implement `IMFByteStream`                                     |
| Android            | `MediaDataSource` (`readAt`, `getSize`)                       |
| GStreamer          | `appsrc` in random-access mode                                |

Source contract requirements:
- Random access: `read(offset, buf, len)` and `size`. Streams are not enough:
  MP4s often keep their index (moov) at the end of the file.
- Thread rules are explicit: backends call from their own threads (AVFoundation
  uses a dispatch queue).
- Reads can be cancelled: an in-flight network read must not stall seek or close.
- Transport errors are distinct from end of file.
- Local fast path: OS backends still receive local paths directly.

Transports. Squeeze spawns the system `ssh` and talks over its stdin/stdout, like
git and rsync. SSH handles keys, the agent, `~/.ssh/config`, and jump hosts. Squeeze
gets no network listener and no auth code of its own.
- **`ssh host -s sftp`**: a minimal SFTP v3 client (open/read/stat/readdir/close).
  Nothing is installed on the remote and there is no version skew. Bytes only.
- **`ssh host squeeze serve`**: our own small protocol. Adds remote probe, listing,
  and thumbnails without moving file bytes. Requires Squeeze on the remote with
  compatible versions. Remote results come from the *remote* backend and may differ
  from the local one.
- Not doing: Squeeze listening on a port (that means owning auth and TLS); FFmpeg
  `sftp://` (needs libssh, is FFmpeg-only, and needs FFmpeg networking enabled).

The real problem is latency, not bandwidth: each read costs a round trip. Playback
needs multiple reads in flight and read-ahead. A seek costs a few round trips.

## Frame Sinks

`Sink :: enum { Window, Hash, Dump, Terminal }`, chosen with a `switch`, not an interface.
Headless sinks skip SDL init and run unpaced (as fast as possible), which also makes
them a decode benchmark.

- **Hash**: per-frame checksums comparable to `ffmpeg -i x.mp4 -f framemd5 -`.
  Proves decode correctness with no window and no disk use. Basis for golden
  tests and Linux validation over SSH.
- **Dump**: `.y4m` (mpv and ffplay play it directly) and `.ppm` stills. Both need
  no encoder; our FFmpeg build has encoders disabled. Needs frame selection
  (`--frames A-B`, `--every N`): 1080p yuv420 is ~3 MB/frame.
- **Terminal**: kitty graphics for single frames and thumbnail grids, not playback.
  `mpv --vo=kitty` lags even in kitty because the protocol sends base64 pixels
  through the pty. `--vo=tct` (text cells) keeps up but is too low-resolution.
  `--vo-kitty-use-shm` played audio only in the terminal tested.

---

## Phases

### Phase 1 — Source in the Open API
- [ ] Decode/open API in `vd.h` takes a source from the start (see `02_odin_video_player.md`)
- [ ] Local-file source proves the seam before any network code
- [ ] Cancellation and error semantics written into the contract

### Phase 2 — Headless Sinks
- [ ] Hash sink; match `ffmpeg -f framemd5` on test media
- [ ] y4m/ppm dump with frame selection
- [ ] Run headless on Linux over SSH; shutdown report works without a window

### Phase 3 — SFTP Source
- [ ] Spawn `ssh host -s sftp`; minimal SFTP v3 client
- [ ] Multiple reads in flight plus read-ahead; measure seek latency vs RTT
- [ ] Play a file from the Linux workstation on the Mac

### Phase 4 — Later / Maybe
- [ ] `squeeze serve`: remote probe/list/thumbnails
- [ ] Terminal sink for stills and thumbnail grids

---

## Quick Experiments (no code)
- `mpv sftp://user@host/path/file.mp4` (works only if mpv's FFmpeg has libssh)
- `sshfs` mount + mpv: shows what remote playback feels like today

---

## Learnings
- (captured as we go)

---

## Completion Checklist

Before archiving this sprint:
- [ ] All phases marked complete
- [ ] docs/references/ guides written for major features
- [ ] Archive: `mv todo.md docs/sprints/completed/YYYY-MM_sources_and_sinks.md`
