package main

// math and other stuff
Vec4 :: [4]f32
Vec3 :: [3]f32
Vec2 :: [2]f32

Vec4i :: [4]i32
Vec3i :: [3]i32
Vec2i :: [2]i32

Color :: Vec4

ColorYellow :: Color{1, 1, 0, 1}
ColorCyan :: Color{0, 1, 1, 1}

App_State :: struct {
	// settings
	vsync:      bool,
	quit_app:   bool,

	// debug
	debug_mode: bool,
}

App_Input :: struct {
	buttons:              [InputAction]Button_State,

	// Mouse
	// Accumulated per-frame
	mouse_scroll_delta:   f32,
	mouse_position:       Vec2,
	mouse_position_delta: Vec2,
	mouse_left:           Button_State,
	mouse_right:          Button_State,
}

app_init :: proc(editor: ^App_State) {

}

app_update_and_render :: proc(app: ^App_State, app_input: ^App_Input, dt: f32, window_width, window_height: u32) {

}
