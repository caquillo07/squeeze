# Desktop Source Debugging

Verified setup: CLion 2026.2.3, Odin Support plugin, native LLDB, macOS arm64.
The user verified Odin → VD → Odin stepping. FFmpeg symbols/source lookup are
verified; live FFmpeg stepping and variable/backtrace inspection remain to check.

## Build Ownership

`justfile` owns Odin compilation. CMake owns VD's C unity build and archive merge.
Both CLion and terminal use the same presets, tools, and configuration directories.
Do not duplicate compiler flags in an Odin Build/Run configuration.

Build dependencies explicitly before building the app:

```sh
just build-ffmpeg                   # Debug: -g3 -O0, no stripping
just vd_config=release build-ffmpeg # Release: -O3, no debug information
just build-desktop                 # Debug VD/FFmpeg; Odin currently always -debug
```

Each VD preset selects matching archives under `build/deps/ffmpeg/<config>/install/`.
Project builds never compile FFmpeg. `just clean` preserves dependencies and source
symlinks; `just clean-all` removes them. Do not run IDE and terminal builds
concurrently in the same configuration directory.

## CLion Configuration

1. Open the root CMake project; configure the shared native toolchain and presets
   as described in [VD build notes](vd_backend.md).
2. Configure the Odin Support plugin's compiler/SDK and Odin source roots.
3. In **Settings → Build, Execution, Deployment → Custom Build Targets**, add
   a target named `Squeeze Desktop`. Select the native toolchain with LLDB.
4. Click **… beside Build**, then **+** to create a project-local build tool:
   - Name: `Build Squeeze Desktop`
   - Program: `/Users/hector/.local/bin/just`
   - Arguments: `build-desktop`
   - Working directory: `$ProjectFileDir$`
5. Select that tool for Build. Leave Clean unset.
6. In **Run → Edit Configurations**, add **Custom Build Application**:
   - Name: `Squeeze Desktop`
   - Target: the custom target above
   - Executable: `/Users/hector/code/squeeze/build/squeeze-desktop`
   - Working directory: `/Users/hector/code/squeeze`
   - Keep the Build before-launch step enabled.

Adjust absolute paths for another checkout. The executable field treated
`$ProjectFileDir$` literally in this setup, so use an absolute path there.
Custom targets cannot select IDE-wide tools from **Settings → Tools → External
Tools**; their build tools are project-local and created via the **…** button.

## Verify Stepping

Reload CMake after changing presets. Debug the Custom Build Application, not the
build tool or CMake smoke target. Break at `vd_hello()` in `desktop/main.odin`, step
into `core/vd/vd_ffmpeg.c`, then into `avformat_version()`. Alternatively, set a
function breakpoint on `avformat_version`.

FFmpeg's configure creates a `src` symlink in each dependency build directory,
pointing to the vendored `ext/ffmpeg/` source. DWARF references that path; no source
mapping is needed while the checkout and dependency directory remain in place.

Check source locations, local variables, and a backtrace containing FFmpeg, VD,
and Odin frames. Exit back through C into Odin. Debug flags do not make stepping
through hand-written assembly source equivalent to stepping through C.

Symbol lookup without launching the app:

```sh
lldb --batch -o 'target create build/squeeze-desktop' \
    -o 'image lookup -v -n avformat_version'
```

The expected result includes `version.c` and a line entry, not only a symbol name.
