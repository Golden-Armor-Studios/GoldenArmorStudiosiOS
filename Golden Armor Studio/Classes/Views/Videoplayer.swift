import UIKit
import UIKit
import UIKit
import AVFoundation

final class Videoplayer {
    private final class VideoContext: NSObject {
        let player: AVPlayer
        let item: AVPlayerItem
        let layer: AVPlayerLayer
        var endObserver: NSObjectProtocol?
        let hostingView: VideoHostingView
        let videoSize: CGSize

        init(player: AVPlayer,
             item: AVPlayerItem,
             layer: AVPlayerLayer,
             hostingView: VideoHostingView,
             videoSize: CGSize) {
            self.player = player
            self.item = item
            self.layer = layer
            self.hostingView = hostingView
            self.videoSize = videoSize
        }
    }

    private final class VideoHostingView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    private static let contexts = NSMapTable<UIView, VideoContext>(keyOptions: .weakMemory, valueOptions: .strongMemory)

    /// Plays a looping video inside `containerView` using a resource path relative to the app bundle.
    /// Example path: `Videos/intro.mp4`
    @discardableResult
    static func playVideo(resourcePath: String, in containerView: UIView, videoGravity: AVLayerVideoGravity = .resizeAspectFill, muted: Bool = true) -> Bool {
        guard let url = url(for: resourcePath) else {
            assertionFailure("Videoplayer: Unable to find video at path \(resourcePath)")
            return false
        }

        stopVideo(in: containerView)

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 0
        #if targetEnvironment(simulator)
        playerItem.preferredMaximumResolution = CGSize(width: 1920, height: 1080)
        #endif

        if asset.duration.isValid && asset.duration.isNumeric {
            let nominalFPS = Double(asset.tracks(withMediaType: .video).first?.nominalFrameRate ?? 0)
            let frameDurationSeconds = nominalFPS > 0 ? (1.0 / nominalFPS) : (1.0 / 30.0)
            let frameDuration = CMTime(seconds: frameDurationSeconds, preferredTimescale: asset.duration.timescale)
            let loopEndTime = CMTimeSubtract(asset.duration, frameDuration)
            if loopEndTime > .zero {
                playerItem.forwardPlaybackEndTime = loopEndTime
            }
        }

        let player = AVPlayer(playerItem: playerItem)
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = false
        player.isMuted = muted

        let hostingView = VideoHostingView()
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.isUserInteractionEnabled = false
        hostingView.backgroundColor = .clear
        containerView.insertSubview(hostingView, at: 0)
        containerView.sendSubviewToBack(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        let playerLayer = hostingView.playerLayer
        playerLayer.player = player
        playerLayer.videoGravity = videoGravity
        let videoSize = naturalSize(for: asset) ?? containerView.bounds.size
        layout(playerLayer: playerLayer, in: containerView, videoSize: videoSize)
        playerLayer.needsDisplayOnBoundsChange = true
        playerLayer.zPosition = -1

        let context = VideoContext(
            player: player,
            item: playerItem,
            layer: playerLayer,
            hostingView: hostingView,
            videoSize: videoSize
        )

        context.endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak containerView] _ in
            guard let containerView, let context = contexts.object(forKey: containerView) else { return }
            context.player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            context.player.playImmediately(atRate: 1.0)
        }

        contexts.setObject(context, forKey: containerView)

        player.playImmediately(atRate: 1.0)
        return true
    }

    /// Resizes the video layer to match the container's current bounds.
    static func updateLayout(for containerView: UIView) {
        guard let context = contexts.object(forKey: containerView) else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        context.hostingView.frame = containerView.bounds
        layout(playerLayer: context.layer, in: containerView, videoSize: context.videoSize)
        CATransaction.commit()
    }

    /// Stops playback and removes any video layer from the container.
    static func stopVideo(in containerView: UIView) {
        guard let context = contexts.object(forKey: containerView) else { return }
        if let observer = context.endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        context.player.pause()
        context.hostingView.removeFromSuperview()
        contexts.removeObject(forKey: containerView)
    }

    private static func url(for resourcePath: String) -> URL? {
        let nsPath = resourcePath as NSString
        let fileName = nsPath.lastPathComponent
        let directory = nsPath.deletingLastPathComponent
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension

        let subdirectory = directory.isEmpty ? nil : directory
        let extensionOrNil = ext.isEmpty ? nil : ext

        if let subdirectory {
            if let url = Bundle.main.url(forResource: name, withExtension: extensionOrNil, subdirectory: subdirectory) {
                return url
            }
        }

        return Bundle.main.url(forResource: name, withExtension: extensionOrNil)
    }

    private static func naturalSize(for asset: AVAsset) -> CGSize? {
        guard let track = asset.tracks(withMediaType: .video).first else { return nil }
        let transformedSize = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
    }

    private static func layout(playerLayer: AVPlayerLayer, in containerView: UIView, videoSize: CGSize) {
        let containerBounds = containerView.bounds
        guard containerBounds.width > 0, containerBounds.height > 0,
              videoSize.width > 0, videoSize.height > 0 else {
            playerLayer.frame = containerBounds
            return
        }

        let videoAspect = videoSize.width / videoSize.height

        var targetSize = CGSize(width: containerBounds.width,
                                height: containerBounds.width / videoAspect)

        if targetSize.height < containerBounds.height {
            targetSize.height = containerBounds.height
            targetSize.width = containerBounds.height * videoAspect
        }

        let originX = (containerBounds.width - targetSize.width) / 2.0
        let originY = containerBounds.height - targetSize.height

        playerLayer.frame = CGRect(origin: CGPoint(x: originX, y: originY), size: targetSize)
    }
}
