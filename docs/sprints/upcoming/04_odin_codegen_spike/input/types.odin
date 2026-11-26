package input

Vec3 :: [3]f32

@(glsl)
Vertex :: struct {
	position:   [3]f32,
	normal:     Vec3,
	tex_coords: [2]f32,
	tint:       [4]f32,
}

@(c_mirror = "vd_heap_stats")
Heap_Stats :: struct {
	allocations: u64,
	frees:       u64,
}
