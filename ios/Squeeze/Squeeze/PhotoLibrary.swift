import Photos
import UIKit

enum PhotoLibraryAuthStatus {
	case notDetermined
	case authorized
	case limited
	case denied
}

func mapAuthStatus(_ status: PHAuthorizationStatus) -> PhotoLibraryAuthStatus {
	switch status {
	case .authorized: return .authorized
	case .limited: return .limited
	case .denied, .restricted: return .denied
	case .notDetermined: return .notDetermined
	@unknown default: return .denied
	}
}

func checkPhotoLibraryAuth() -> PhotoLibraryAuthStatus {
	mapAuthStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
}

func requestPhotoLibraryAuth() async -> PhotoLibraryAuthStatus {
	await mapAuthStatus(PHPhotoLibrary.requestAuthorization(for: .readWrite))
}

func fetchAllAssets() -> PHFetchResult<PHAsset> {
	let options = PHFetchOptions()
	options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
	return PHAsset.fetchAssets(with: options)
}

func getFileSize(for asset: PHAsset) async -> Int64? {
	await Task.detached {
		guard let resource = PHAssetResource.assetResources(for: asset).first else { return nil }
		guard let size = resource.value(forKey: "fileSize") as? CLong else { return nil }
		return Int64(size)
	}.value
}

func formatFileSize(_ bytes: Int64) -> String {
	let formatter = ByteCountFormatter()
	formatter.countStyle = .binary
	return formatter.string(fromByteCount: bytes)
}

func formatDuration(_ seconds: TimeInterval) -> String {
	let mins = Int(seconds) / 60
	let secs = Int(seconds) % 60
	return String(format: "%d:%02d", mins, secs)
}
