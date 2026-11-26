# Sprint: Odin AST Code Generation

**Started:** [Date]
**Status:** Not Started — start when the first real shader interface or script binding exists

## Goal
Odin declarations are the single source of truth for data and procedures that another
language must also see. A small generator reads tagged declarations with `core:odin/parser`
and writes the GLSL and binding code, so the two sides can't drift apart.

## Context
The idea comes from a talk: tag a declaration with a custom attribute, parse the package with
`core:odin/ast`, and emit the code that would otherwise be written by hand.

```odin
@(glsl)                                   // → generated.glsl
Vertex :: struct {                        //   struct Vertex {
	position:   [3]f32,                   //       vec3 position;
	tex_coords: [2]f32,                   //       vec2 tex_coords;
}                                         //   };

@(lua_callable)                           // → generated.odin
add :: proc(a: f32, b: f32) -> f32 {...}  //   luacall_add :: proc "c" (L: ^lua.State) -> i32 {
                                          //       a := lua.checknumber(L, 1) ...
```

Spike (2026-11-08, `dev-2026-11-nightly:9a69916`, kept in `04_odin_codegen_spike/`, run `odin run gen -- "$PWD/input"` from there):
- About 60 lines of Odin reproduce the `@(glsl)` example: `parser.parse_package_from_path`,
  walk `file.decls` for `^ast.Value_Decl`, read `decl.attributes`, map `^ast.Struct_Type`
  fields to GLSL types.
- `@(glsl)` and `@(c_mirror = "name")` both show up in `Attribute.elems` (as `^ast.Ident`
  and `^ast.Field_Value`).
- The compiler rejects unknown attributes (`Unknown attribute element name 'glsl'`) unless you
  pass `-custom-attribute:glsl,...`. Every justfile recipe that builds, checks, or runs desktop Odin code
  (`build-desktop`, `check-desktop`) needs this flag.
- **The AST is untyped.** `normal: Vec3`, where `Vec3 :: [3]f32`, comes out as an unresolved
  identifier. The parser sees syntax only, so it doesn't resolve aliases, imported types, or
  constants.

### Where it pays off in Squeeze
1. **Shader interfaces (first target).** `desktop/gpu_renderer.odin` and `desktop/shaders/*.glsl`
   will share vertex layouts and uniform blocks once video rendering is real: YUV→RGB
   color-matrix uniforms, frame/HUD quads. Today `frame.vert.glsl` is a stub and no structs are
   shared, so nothing exists to generate yet.
2. **Script bindings.** `upcoming/02_odin_video_player.md` plans a QuickJS overlay system. An
   `@(js_callable)` attribute that generates the `JSValue` argument unpacking and return wrapper
   is the same idea as the Lua slide, and it removes the most repetitive glue in that sprint.
3. **Odin↔C struct mirrors (low value, wrong direction).** `Heap_Stats` mirrors
   `vd_heap_stats`, and a `#assert` / `_Static_assert` pair on the size guards it. VD's C header
   owns that type, and VD builds and tests without Odin, so generating C from Odin is backwards
   here. If mirrors multiply, a C→Odin generator (libclang, e.g. `odin-c-bindgen`) fits better.
   This tool isn't the place for it.

---

## Phases

### Phase 1 — Generator Skeleton
- [ ] `tools/codegen/` Odin program: `codegen <package dir> <out dir>`. Parses once and
      dispatches on attribute name
- [ ] Explicit type table (`f32`→`float`, `[N]f32`→`vecN`, `matrix[4,4]f32`→`mat4`, …). Unknown
      types and aliases are a **hard error with file:line**, never a silent guess. Resolve local
      `X :: <type>` aliases from the same package only if we need them
- [ ] `just gen` runs it. `-custom-attribute:` list added to every `odin build/check` in the justfile
- [ ] Decide where output goes. Recommendation: commit it (reviewable diffs, greppable, builds
      without the tool) and add `just gen-check`, which fails if regenerating changes anything

### Phase 2 — GLSL Shader Interfaces
- [ ] `@(glsl)` structs → one generated `.glsl` include. `glslc -I` in the shader recipe
- [ ] **Layout is the real problem, not names.** Uniform buffers use std140, storage buffers std430;
      `vec3` aligns to 16 bytes and std140 array strides round up to 16. Choose the rule:
      either reject `[3]f32` in uniform structs, or emit explicit padding. Generate Odin
      `#assert(offset_of(T, f) == N)` checks next to the GLSL so a layout mismatch fails at compile time
- [ ] Vertex inputs: generate `layout(location = N) in` declarations and the matching
      `SDL_GPUVertexAttribute` array (format and offset) for the pipeline
- [ ] Verify by deliberately breaking a field order and confirming the build fails

### Phase 3 — Script Bindings (with the overlay system)
- [ ] `@(js_callable)` procs → generated `proc "c"` QuickJS wrappers plus a registration table
- [ ] Support only the parameter and return types the overlays actually use. Reject the rest
      with file:line
- [ ] Context: wrappers are `proc "c"`, so they need an explicit `context` from the script
      host, not `runtime.default_context()` scattered everywhere

---

## Open Questions
- AST vs typed information. If alias/import resolution becomes painful, look at `odin doc`'s
  typed output (`core:odin/doc-format`), or at a generator that imports the package and walks
  `type_info_of` (exact sizes and offsets, but it can't see attributes). Start with the AST and
  a strict type table.
- Does the generator run on every build or only on demand? This depends on how fast it is
  and on the committed-output decision.

## Learnings
- (captured as we go)

## Completion Checklist
- [ ] Generated output verified against hand-written equivalents
- [ ] Deliberate mismatches fail the build
- [ ] `docs/references/codegen.md`: attributes, type table, layout rules, how to add a backend
- [ ] Archive to `docs/sprints/completed/`
