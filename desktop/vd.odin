package main

foreign import vd "../build/desktop/libvd.a"

@(default_calling_convention = "c")
foreign vd {
	vd_hello :: proc() ---
}
