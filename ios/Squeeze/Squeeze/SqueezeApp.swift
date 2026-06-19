import SwiftUI

@main
struct SqueezeApp: App {
	init() {
		let version = String(cString: squeeze_version())
		let sum = squeeze_add(40, 2)
		print("[Squeeze] Odin core v\(version), 40 + 2 = \(sum)")
		vd_hello()
	}

	var body: some Scene {
		WindowGroup {
			RootView()
		}
	}
}
