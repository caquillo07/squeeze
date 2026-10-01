# Vendored FFmpeg

- Version: **9.0.2**, as reported by the supplied release archive and `VERSION`.
- Upstream source URL: https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz
- Archive SHA-256: `8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e`
- Imported from the user-supplied archive; upstream authenticity/latest-release
  status was not independently verified because network access was blocked.
- Source extracted into `ext/ffmpeg/` with its top-level directory stripped.
- Upstream source is unmodified. Build artifacts live under `build/deps/ffmpeg/`.
- Keep `LICENSE.md` and `COPYING.*` in the source tree. Our current configuration
  reports **LGPL version 2.1 or later**; GPL, nonfree, and version3 are disabled.
  Merely retaining upstream GPL-licensed optional sources does not enable them.

## Build

```sh
just build-ffmpeg                  # explicit incremental Debug dependency build
just vd_config=release build-ffmpeg # explicit incremental Release dependency build
just smoke-vd                      # merged archive + smoke tests; FFmpeg must exist
just vd_backend=stub smoke-vd      # no FFmpeg compilation/linking
just build-desktop                 # desktop links only libvd.a for VD
just vd_backend=stub build-desktop
```

macOS arm64 only for now. Uses `/usr/bin/clang`, the platform SDK, and modern GNU
Make at `~/.local/bin/make`; VD additionally uses CMake. No downloads or
package-manager library lookup. `FFMPEG_JOBS` overrides the default eight jobs.

Debug and Release build/install separately under `build/deps/ffmpeg/debug/` and
`build/deps/ffmpeg/release/`. Debug uses `-g3 -O0`, retains frame pointers, disables
compiler optimizations and stripping. Release uses `-O3` without debug information.
The corresponding VD preset selects that configuration's `install/` directory.
Normal project builds never compile FFmpeg. The `vd_config` selector controls C
and FFmpeg, not Odin compilation.

Changing configure flags triggers reconfiguration. Delete the affected dependency
configuration directory for a clean rebuild after replacing the vendored
release/toolchain. The former `build/deps/ffmpeg/install/` is no longer consumed.
See [desktop debugger setup](../docs/references/desktop_debugging.md).

The minimal configuration enables local MP4/MOV demuxing, H.264 decoding/parsing,
and the five libraries (`avformat`, `avcodec`, `avutil`, `swscale`, `swresample`).
No encoders, network protocols, external libraries, or hardware accelerators.
Add codecs/formats explicitly in `scripts/build_ffmpeg.sh` when needed.

The VD smoke test references all five library versions through the public API.
The backend-private smoke test opens an H.264 decoder without feeding media,
allocates/frees format and frame resources, and verifies tiny pixel and audio
sample conversions. It is not a video playback implementation or a media test.

The original tarball is not required by the build: commit the extracted source,
not a second binary copy. See `docs/references/vd_backend.md` for the boundary.
