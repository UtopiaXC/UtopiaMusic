import Foundation
import MediaPlayer
import Flutter

class NowPlayingHandler: NSObject, FlutterPlugin {
    static var channel: FlutterMethodChannel?

    static func register(with registrar: FlutterPluginRegistrar) {
        channel = FlutterMethodChannel(
            name: "com.utopiaxc.utopia.music/now_playing",
            binaryMessenger: registrar.messenger()
        )
        let instance = NowPlayingHandler()
        registrar.addMethodCallDelegate(instance, channel: channel!)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            setupRemoteCommandCenter()
            result(nil)

        case "updateNowPlaying":
            if let args = call.arguments as? [String: Any] {
                updateNowPlayingInfo(args)
            }
            result(nil)

        case "updatePosition":
            if let args = call.arguments as? [String: Any] {
                updatePosition(args)
            }
            result(nil)

        case "updatePlaybackState":
            if let args = call.arguments as? [String: Any] {
                updatePlaybackState(args)
            }
            result(nil)

        case "updateCommandState":
            if let args = call.arguments as? [String: Any] {
                updateCommandState(args)
            }
            result(nil)

        case "clearNowPlaying":
            clearNowPlayingInfo()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            NowPlayingHandler.channel?.invokeMethod("onPlay", arguments: nil)
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            NowPlayingHandler.channel?.invokeMethod("onPause", arguments: nil)
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            NowPlayingHandler.channel?.invokeMethod("onPlayPause", arguments: nil)
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            NowPlayingHandler.channel?.invokeMethod("onNext", arguments: nil)
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            NowPlayingHandler.channel?.invokeMethod("onPrevious", arguments: nil)
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                NowPlayingHandler.channel?.invokeMethod("onSeek", arguments: positionEvent.positionTime)
            }
            return .success
        }
    }

    private func updateCommandState(_ args: [String: Any]) {
        let commandCenter = MPRemoteCommandCenter.shared()

        if let hasNext = args["hasNext"] as? Bool {
            commandCenter.nextTrackCommand.isEnabled = hasNext
        }

        if let hasPrevious = args["hasPrevious"] as? Bool {
            commandCenter.previousTrackCommand.isEnabled = hasPrevious
        }
    }

    private func updateNowPlayingInfo(_ args: [String: Any]) {
        var nowPlayingInfo = [String: Any]()

        if let title = args["title"] as? String {
            nowPlayingInfo[MPMediaItemPropertyTitle] = title
        }

        if let artist = args["artist"] as? String {
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        }

        if let duration = args["duration"] as? Double {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }

        if let position = args["position"] as? Double {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        }

        if let rate = args["playbackRate"] as? Double {
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        if let albumArtUrl = args["albumArt"] as? String, let url = URL(string: albumArtUrl) {
            DispatchQueue.global().async {
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    DispatchQueue.main.async {
                        var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        currentInfo[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                    }
                }
            }
        }
    }

    private func updatePosition(_ args: [String: Any]) {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]

        if let position = args["position"] as? Double {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        }

        if let rate = args["playbackRate"] as? Double {
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func updatePlaybackState(_ args: [String: Any]) {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]

        if let position = args["position"] as? Double {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        }

        if let rate = args["playbackRate"] as? Double {
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
    }
}