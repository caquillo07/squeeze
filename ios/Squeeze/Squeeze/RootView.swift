import Photos
import SwiftUI
import UIKit

struct RootView: View {
	@State private var authStatus = checkPhotoLibraryAuth()
	@State private var assets: PHFetchResult<PHAsset>?
	@State private var galleryReady = false
	@State private var galleryOpacity: Double = 0

	private static let warmupCount = 21

	var body: some View {
		Group {
			switch authStatus {
			case .authorized, .limited:
				if let assets, galleryReady {
					GalleryView(assets: assets, onAppear: nil)
						.opacity(self.galleryOpacity)
						.onAppear {
							withAnimation(.easeOut(duration: 0.18)) {
								self.galleryOpacity = 1
							}
						}
				} else {
					Color.black
						.ignoresSafeArea()
						.task { await self.warmup() }
				}
			case .denied:
				VStack(spacing: 12) {
					Image(systemName: "photo.on.rectangle.angled")
						.font(.largeTitle)
						.foregroundStyle(.secondary)
					Text("Photo Library Access Required")
						.font(.headline)
					Text("Open Settings to grant access.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
			case .notDetermined:
				Color.clear
					.task {
						authStatus = await requestPhotoLibraryAuth()
					}
			}
		}
	}

	private func warmup() async {
		guard self.assets == nil else { return }
		let fetched = fetchAllAssets()
		self.assets = fetched
		print("[Squeeze] Loaded \(fetched.count) assets")

		await Self.prefetchNewest(fetched, count: Self.warmupCount)

		await MainActor.run {
			self.galleryReady = true
		}
	}

	private static func prefetchNewest(
		_ assets: PHFetchResult<PHAsset>, count: Int
	) async {
		guard assets.count > 0 else { return }
		let limit = min(count, assets.count)
		let manager = PHImageManager.default()
		let options: PHImageRequestOptions = {
			let o = PHImageRequestOptions()
			o.deliveryMode = .highQualityFormat
			o.resizeMode = .exact
			o.isNetworkAccessAllowed = false
			o.isSynchronous = false
			return o
		}()

		await withTaskGroup(of: Void.self) { group in
			for index in (assets.count - limit)..<assets.count {
				let asset = assets.object(at: index)
				group.addTask {
					await withCheckedContinuation {
						(continuation: CheckedContinuation<Void, Never>) in
						let target = CGSize(width: 400, height: 400)
						manager.requestImage(
							for: asset,
							targetSize: target,
							contentMode: .aspectFill,
							options: options
						) { _, info in
							let isDegraded =
								(info?[PHImageResultIsDegradedKey] as? Bool) ?? false
							if !isDegraded {
								continuation.resume()
							}
						}
					}
				}
			}
		}
	}
}

#Preview {
	RootView()
}
