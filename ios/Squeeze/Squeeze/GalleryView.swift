import Photos
import SwiftUI
import UIKit

struct GalleryView: UIViewControllerRepresentable {
	let assets: PHFetchResult<PHAsset>
	var onAppear: (() -> Void)?

	func makeUIViewController(context: Context) -> GalleryViewController {
		return GalleryViewController(assets: self.assets, onAppear: self.onAppear)
	}

	func updateUIViewController(_ viewController: GalleryViewController, context: Context) {
		viewController.updateAssets(self.assets)
	}
}

final class GalleryViewController: UIViewController {
	private let collectionView: UICollectionView
	private let imageManager = PHImageManager.default()
	private let imageRequestOptions: PHImageRequestOptions
	private let thumbnailStore = NSCache<NSString, UIImage>()
	private var assets: PHFetchResult<PHAsset>
	private var imageRequests: [IndexPath: PHImageRequestID] = [:]
	private var prefetchRequests: [IndexPath: PHImageRequestID] = [:]
	private var fileSizeStore: [String: Int64] = [:]
	private var fileSizeTasks: [IndexPath: Task<Void, Never>] = [:]
	private var detailOverlayView: UIView?
	private var detailImageView: UIImageView?
	private var detailMetadataView: UIView?
	private var detailSourceIndexPath: IndexPath?
	private let onAppear: (() -> Void)?
	private var didPerformInitialScroll = false

	private let columnCount = 3
	private let spacing: CGFloat = 2
	private let maxFileSizeTaskCount = 2

	private var thumbnailSize: CGSize {
		let cellSize = self.itemSideLength * self.view.windowScale
		return CGSize(width: cellSize, height: cellSize)
	}

	private var itemSideLength: CGFloat {
		let totalSpacing = self.spacing * CGFloat(self.columnCount - 1)
		let availableWidth = self.collectionView.bounds.width - totalSpacing
		return floor(availableWidth / CGFloat(self.columnCount))
	}

	init(assets: PHFetchResult<PHAsset>, onAppear: (() -> Void)? = nil) {
		self.assets = assets
		self.onAppear = onAppear
		self.imageRequestOptions = GalleryViewController.makeImageRequestOptions()

		let layout = UICollectionViewFlowLayout()

		self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

		super.init(nibName: nil, bundle: nil)

		layout.minimumInteritemSpacing = self.spacing
		layout.minimumLineSpacing = self.spacing
		self.thumbnailStore.countLimit = 120
		self.collectionView.dataSource = self
		self.collectionView.delegate = self
		self.collectionView.prefetchDataSource = self
		self.collectionView.backgroundColor = .systemBackground
		self.collectionView.register(
			GalleryCell.self, forCellWithReuseIdentifier: GalleryCell.reuseIdentifier,
		)
	}

	required init?(coder: NSCoder) {
		nil
	}

	override func loadView() {
		self.view = self.collectionView
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		self.updateItemSize()
		self.updateThumbnailStoreLimit()
		self.scrollToBottomOnFirstLayout()
	}

	private func scrollToBottomOnFirstLayout() {
		guard !self.didPerformInitialScroll else { return }
		guard self.itemSideLength > 0 else { return }
		guard self.assets.count > 0 else { return }

		self.didPerformInitialScroll = true

		let lastItem = self.assets.count - 1
		let lastSection = self.collectionView.numberOfSections - 1
		guard lastSection >= 0 else { return }
		let indexPath = IndexPath(item: lastItem, section: lastSection)

		self.collectionView.scrollToItem(at: indexPath, at: .bottom, animated: false)
		self.collectionView.layoutIfNeeded()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		self.onAppear?()
	}

	func updateAssets(_ assets: PHFetchResult<PHAsset>) {
		if self.assets === assets {
			return
		}

		self.cancelAllImageRequests()
		self.cancelAllPrefetchRequests()
		self.cancelAllFileSizeTasks()
		self.thumbnailStore.removeAllObjects()
		self.fileSizeStore.removeAll(keepingCapacity: true)
		self.assets = assets
		self.collectionView.reloadData()
		self.updateThumbnailStoreLimit()
	}

	private func updateItemSize() {
		guard let layout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout
		else { return }

		let side = self.itemSideLength
		if layout.itemSize == CGSize(width: side, height: side) {
			return
		}

		layout.itemSize = CGSize(width: side, height: side)
		layout.invalidateLayout()
	}

	private func updateThumbnailStoreLimit() {
		let visibleCount = self.estimatedVisibleCellCount
		self.thumbnailStore.countLimit = max(visibleCount * 6, 60)
	}

	private var estimatedVisibleCellCount: Int {
		let itemLength = self.itemSideLength
		if itemLength <= 0 {
			return 1
		}

		let rowCount = Int(ceil(self.collectionView.bounds.height / itemLength))
		return max(rowCount * self.columnCount, 1)
	}

	private static func makeImageRequestOptions() -> PHImageRequestOptions {
		let options = PHImageRequestOptions()
		options.deliveryMode = .opportunistic
		options.resizeMode = .fast
		options.isNetworkAccessAllowed = false
		return options
	}

	private func requestThumbnail(for asset: PHAsset, indexPath: IndexPath, cell: GalleryCell) {
		self.cancelImageRequest(at: indexPath)
		self.cancelPrefetchRequest(at: indexPath)

		let cacheKey = self.thumbnailCacheKey(for: asset)
		if let cachedImage = self.thumbnailStore.object(forKey: cacheKey) {
			cell.setThumbnail(cachedImage)
			return
		}

		let requestID = self.imageManager.requestImage(
			for: asset,
			targetSize: self.thumbnailSize,
			contentMode: .aspectFill,
			options: self.imageRequestOptions,
		) { [weak self] image, info in
			guard let self else { return }

			let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
			if cancelled {
				return
			}

			let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false

			if !degraded {
				self.imageRequests[indexPath] = nil
				if let image {
					self.thumbnailStore.setObject(image, forKey: cacheKey)
				}
			}

			guard cell.assetIdentifier == asset.localIdentifier else { return }

			if let image {
				cell.setThumbnail(image)
			}
		}

		if self.thumbnailStore.object(forKey: cacheKey) == nil {
			self.imageRequests[indexPath] = requestID
		}
	}

	private func cancelImageRequest(at indexPath: IndexPath) {
		guard let requestID = self.imageRequests[indexPath] else { return }
		self.imageManager.cancelImageRequest(requestID)
		self.imageRequests[indexPath] = nil
	}

	private func cancelAllImageRequests() {
		for requestID in self.imageRequests.values {
			self.imageManager.cancelImageRequest(requestID)
		}
		self.imageRequests.removeAll(keepingCapacity: true)
	}

	private func cancelPrefetchRequest(at indexPath: IndexPath) {
		guard let requestID = self.prefetchRequests[indexPath] else { return }
		self.imageManager.cancelImageRequest(requestID)
		self.prefetchRequests[indexPath] = nil
	}

	private func cancelAllPrefetchRequests() {
		for requestID in self.prefetchRequests.values {
			self.imageManager.cancelImageRequest(requestID)
		}
		self.prefetchRequests.removeAll(keepingCapacity: true)
	}

	private func thumbnailCacheKey(for asset: PHAsset) -> NSString {
		asset.localIdentifier as NSString
	}

	private func requestFileSize(for asset: PHAsset, indexPath: IndexPath, cell: GalleryCell) {
		self.cancelFileSizeTask(at: indexPath)

		if let fileSize = self.fileSizeStore[asset.localIdentifier] {
			cell.setFileSize(fileSize)
			return
		}

		if self.fileSizeTasks.count >= self.maxFileSizeTaskCount {
			return
		}

		self.fileSizeTasks[indexPath] = Task { [weak self, weak cell] in
			let fileSize = await getFileSize(for: asset)

			await MainActor.run {
				guard let self else { return }
				if Task.isCancelled {
					return
				}

				self.fileSizeTasks[indexPath] = nil

				guard let fileSize else { return }
				self.fileSizeStore[asset.localIdentifier] = fileSize

				guard let cell, cell.assetIdentifier == asset.localIdentifier else { return }
				cell.setFileSize(fileSize)
				self.requestFileSizesForVisibleCells()
			}
		}
	}

	private func cancelFileSizeTask(at indexPath: IndexPath) {
		guard let task = self.fileSizeTasks[indexPath] else { return }
		task.cancel()
		self.fileSizeTasks[indexPath] = nil
	}

	private func cancelAllFileSizeTasks() {
		for task in self.fileSizeTasks.values {
			task.cancel()
		}
		self.fileSizeTasks.removeAll(keepingCapacity: true)
	}

	private func requestFileSizesForVisibleCells() {
		for indexPath in self.collectionView.indexPathsForVisibleItems {
			if self.fileSizeTasks.count >= self.maxFileSizeTaskCount {
				return
			}

			guard let cell = self.collectionView.cellForItem(at: indexPath) as? GalleryCell else {
				continue
			}
			let asset = self.assets.object(at: indexPath.item)

			self.requestFileSize(for: asset, indexPath: indexPath, cell: cell)
		}
	}

	private func showDetail(for cell: GalleryCell, at indexPath: IndexPath) {
		guard self.detailOverlayView == nil else { return }
		guard let image = cell.thumbnailImage else { return }

		print("showing detail\n")
		let containerView = self.view
		if let window = self.view.window {
			window
		}
		let overlayView = UIView(frame: containerView.bounds)
		overlayView.backgroundColor = .black
		overlayView.alpha = 0
		containerView.addSubview(overlayView)

		let sourceFrame = cell.convert(cell.bounds, to: overlayView)

		let imageView = UIImageView(image: image)
		imageView.contentMode = .scaleAspectFill
		imageView.clipsToBounds = true
		imageView.frame = sourceFrame

		let metadataView = UIView()
		metadataView.backgroundColor = .systemBlue.withAlphaComponent(0.35)
		metadataView.frame = self.detailMetadataFrame(in: overlayView)
		metadataView.alpha = 0

		overlayView.addSubview(imageView)
		overlayView.addSubview(metadataView)

		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissDetail))
		overlayView.addGestureRecognizer(tapGesture)

		self.detailOverlayView = overlayView
		self.detailImageView = imageView
		self.detailMetadataView = metadataView
		self.detailSourceIndexPath = indexPath
		cell.isHidden = true

		UIView.animate(
			withDuration: 0.28,
			delay: 0,
			options: [.curveEaseInOut, .allowUserInteraction],
		) {
			overlayView.alpha = 1
			imageView.frame = self.detailImageFrame(for: image, in: overlayView)
			imageView.contentMode = .scaleAspectFit
			metadataView.alpha = 1
		}
	}

	@objc private func dismissDetail() {
		guard let overlayView = self.detailOverlayView else { return }
		guard let imageView = self.detailImageView else { return }
		guard let metadataView = self.detailMetadataView else { return }

		let sourceCell = self.detailSourceIndexPath.flatMap {
			self.collectionView.cellForItem(at: $0) as? GalleryCell
		}
		let sourceFrame: CGRect = if let sourceCell {
			sourceCell.convert(sourceCell.bounds, to: overlayView)
		} else {
			imageView.frame
		}

		UIView.animate(
			withDuration: 0.24,
			delay: 0,
			options: [.curveEaseInOut, .allowUserInteraction],
		) {
			overlayView.alpha = 0
			imageView.frame = sourceFrame
			imageView.contentMode = .scaleAspectFill
			metadataView.alpha = 0
		} completion: { _ in
			sourceCell?.isHidden = false
			overlayView.removeFromSuperview()
			self.detailOverlayView = nil
			self.detailImageView = nil
			self.detailMetadataView = nil
			self.detailSourceIndexPath = nil
		}
	}

	private func detailImageFrame(for image: UIImage, in overlayView: UIView) -> CGRect {
		let metadataFrame = self.detailMetadataFrame(in: overlayView)
		let topInset = overlayView.safeAreaInsets.top
		let availableFrame = CGRect(
			x: 0,
			y: topInset,
			width: overlayView.bounds.width,
			height: max(metadataFrame.minY - topInset, 1),
		)
		return self.aspectFitFrame(imageSize: image.size, in: availableFrame)
	}

	private func detailMetadataFrame(in overlayView: UIView) -> CGRect {
		let bottomInset = overlayView.safeAreaInsets.bottom
		let height: CGFloat = 240
		return CGRect(
			x: 0,
			y: overlayView.bounds.height - bottomInset - height,
			width: overlayView.bounds.width,
			height: height + bottomInset,
		)
	}

	private func aspectFitFrame(imageSize: CGSize, in bounds: CGRect) -> CGRect {
		if imageSize.width <= 0 || imageSize.height <= 0 {
			return bounds
		}

		let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
		let width = imageSize.width * scale
		let height = imageSize.height * scale
		return CGRect(
			x: bounds.midX - width / 2,
			y: bounds.midY - height / 2,
			width: width,
			height: height,
		)
	}
}

extension GalleryViewController: UICollectionViewDataSource {
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
		-> Int
	{
		self.assets.count
	}

	func collectionView(
		_ collectionView: UICollectionView,
		cellForItemAt indexPath: IndexPath,
	) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(
			withReuseIdentifier: GalleryCell.reuseIdentifier,
			for: indexPath,
		)
		guard let cell = cell as? GalleryCell else {
			return UICollectionViewCell()
		}

		let asset = self.assets.object(at: indexPath.item)
		cell.display(asset: asset)

		if cell.assetIdentifier == asset.localIdentifier, let image = cell.displayImage {
			cell.setThumbnail(image)
		}

		return cell
	}
}

extension GalleryViewController: UICollectionViewDelegate {
	func collectionView(
		_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell,
		forItemAt indexPath: IndexPath,
	) {
		guard let cell = cell as? GalleryCell else { return }
		let asset = self.assets.object(at: indexPath.item)
		self.requestThumbnail(for: asset, indexPath: indexPath, cell: cell)
		self.requestFileSize(for: asset, indexPath: indexPath, cell: cell)
	}

	func collectionView(
		_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell,
		forItemAt indexPath: IndexPath,
	) {
		self.cancelImageRequest(at: indexPath)
		self.cancelFileSizeTask(at: indexPath)
	}

	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		guard let cell = collectionView.cellForItem(at: indexPath) as? GalleryCell else { return }
		self.showDetail(for: cell, at: indexPath)
	}
}

extension GalleryViewController: UICollectionViewDataSourcePrefetching {
	func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
		for indexPath in indexPaths {
			self.prefetchThumbnail(at: indexPath)
		}
	}

	func collectionView(
		_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath],
	) {
		for indexPath in indexPaths {
			self.cancelPrefetchRequest(at: indexPath)
		}
	}

	private func prefetchThumbnail(at indexPath: IndexPath) {
		if indexPath.item >= self.assets.count {
			return
		}

		if self.prefetchRequests[indexPath] != nil {
			return
		}

		let asset = self.assets.object(at: indexPath.item)
		let cacheKey = self.thumbnailCacheKey(for: asset)
		if self.thumbnailStore.object(forKey: cacheKey) != nil {
			return
		}

		let requestID = self.imageManager.requestImage(
			for: asset,
			targetSize: self.thumbnailSize,
			contentMode: .aspectFill,
			options: self.imageRequestOptions,
		) { [weak self] image, info in
			guard let self else { return }

			let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
			if cancelled {
				return
			}

			let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
			if degraded {
				return
			}

			self.prefetchRequests[indexPath] = nil

			if let image {
				self.thumbnailStore.setObject(image, forKey: cacheKey)
			}
		}

		if self.thumbnailStore.object(forKey: cacheKey) == nil {
			self.prefetchRequests[indexPath] = requestID
		}
	}
}

private final class GalleryCell: UICollectionViewCell {
	static let reuseIdentifier = "GalleryCell"

	private let imageView = UIImageView()
	private let fileSizeLabel = UILabel()
	private let durationLabel = UILabel()
	private(set) var assetIdentifier = ""

	var displayImage: UIImage?

	override init(frame: CGRect) {
		super.init(frame: frame)

		self.contentView.backgroundColor = .systemGray5
		self.contentView.clipsToBounds = true

		self.imageView.contentMode = .scaleAspectFill
		self.imageView.clipsToBounds = true
		self.imageView.translatesAutoresizingMaskIntoConstraints = false

		self.durationLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
		self.durationLabel.textColor = .white
		self.durationLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
		self.durationLabel.layer.cornerRadius = 4
		self.durationLabel.clipsToBounds = true
		self.durationLabel.translatesAutoresizingMaskIntoConstraints = false

		self.fileSizeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
		self.fileSizeLabel.textColor = .white
		self.fileSizeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
		self.fileSizeLabel.layer.cornerRadius = 4
		self.fileSizeLabel.clipsToBounds = true
		self.fileSizeLabel.translatesAutoresizingMaskIntoConstraints = false

		self.contentView.addSubview(self.imageView)
		self.contentView.addSubview(self.fileSizeLabel)
		self.contentView.addSubview(self.durationLabel)

		NSLayoutConstraint.activate([
			self.imageView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor),
			self.imageView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor),
			self.imageView.topAnchor.constraint(equalTo: self.contentView.topAnchor),
			self.imageView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor),

			self.durationLabel.trailingAnchor.constraint(
				equalTo: self.contentView.trailingAnchor, constant: -4,
			),
			self.durationLabel.bottomAnchor.constraint(
				equalTo: self.contentView.bottomAnchor, constant: -4,
			),

			self.fileSizeLabel.centerXAnchor.constraint(equalTo: self.contentView.centerXAnchor),
			self.fileSizeLabel.bottomAnchor.constraint(
				equalTo: self.contentView.bottomAnchor, constant: -4,
			),
		])
	}

	required init?(coder: NSCoder) {
		nil
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		self.assetIdentifier = ""
		self.fileSizeLabel.isHidden = true
		self.fileSizeLabel.text = nil
		self.durationLabel.isHidden = true
		self.durationLabel.text = nil
	}

	func display(asset: PHAsset) {
		self.assetIdentifier = asset.localIdentifier

		if asset.mediaType == .video {
			self.durationLabel.text = " \(formatDuration(asset.duration)) "
			self.durationLabel.isHidden = false
		} else {
			self.durationLabel.isHidden = true
			self.durationLabel.text = nil
		}

		self.fileSizeLabel.isHidden = true
		self.fileSizeLabel.text = nil
	}

	func setThumbnail(_ image: UIImage) {
		self.displayImage = image
		self.imageView.image = image
	}

	var thumbnailImage: UIImage? {
		self.imageView.image
	}

	func setFileSize(_ fileSize: Int64) {
		self.fileSizeLabel.text = " \(formatFileSize(fileSize)) "
		self.fileSizeLabel.isHidden = false
	}

	private func reset() {
		self.assetIdentifier = ""
		self.displayImage = nil
		self.imageView.image = nil
		self.fileSizeLabel.isHidden = true
		self.fileSizeLabel.text = nil
		self.durationLabel.isHidden = true
		self.durationLabel.text = nil
	}
}

private extension UIView {
	var windowScale: CGFloat {
		window?.screen.scale ?? traitCollection.displayScale
	}
}

#Preview {
	GalleryView(assets: PHAsset.fetchAssets(with: nil))
}
