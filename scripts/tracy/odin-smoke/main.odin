package main

import "core:fmt"
import tracy "ext:odin-tracy"

// Links the vendored client and exercises zones, frame marks, and plots without a
// viewer. Verifies the build and binding ABI, not capture; connect the viewer for that.
main :: proc() {
	#assert(tracy.TRACY_ENABLE, "build with -define:TRACY_ENABLE=true")
	tracy.SetThreadName("main")
	for frame in 0 ..< 3 {
		{
			tracy.ZoneN("smoke_zone")
			tracy.PlotI("smoke_frame", i64(frame))
		}
		tracy.FrameMark()
	}
	fmt.printf("Odin → local Tracy client: zones/frames/plots OK (viewer connected: %v)\n", tracy.IsConnected())
	return
}
