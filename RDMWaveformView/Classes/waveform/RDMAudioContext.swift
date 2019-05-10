//
// Copyright 2013 - 2017, William Entriken and the FDWaveformView contributors.
// Copyright 2019, HANAI Tohru.
//
import UIKit
import AVFoundation

/// Holds audio information used for building waveforms
public struct RDMAudioContext {

  /// The audio asset URL used to load the context
  public let audioURL: URL

  /// Count of sample data per second.
  public let sampleRate: Int

  /// Total number of samples in loaded asset
  public let totalSamples: Int

  /// Count of sound channels.
  public let channelCount: Int

  /// Loaded asset
  public let asset: AVAsset

  // Loaded assetTrack
  public let assetTrack: AVAssetTrack
}

extension RDMAudioContext {
  public static func load(fromAudioURL audioURL: URL, completionHandler: @escaping (_ audioContext: Result<RDMAudioContext, RDMAudioError>) -> ()) {
    let asset = AVURLAsset(url: audioURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: NSNumber(value: true)])

    guard let assetTrack = asset.tracks(withMediaType: AVMediaType.audio).first else {
      completionHandler(.failure(RDMAudioError("The track does not contain audio")))
      return
    }

    asset.loadValuesAsynchronously(forKeys: ["duration"]) {
      var error: NSError?
      let status = asset.statusOfValue(forKey: "duration", error: &error)
      switch status {
      case .loaded:
        guard
          let formatDescriptions = assetTrack.formatDescriptions as? [CMAudioFormatDescription],
          let audioFormatDesc = formatDescriptions.first,
          let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDesc)
          else { break }

        let totalSamples = Int((asbd.pointee.mSampleRate) * Float64(asset.duration.value) / Float64(asset.duration.timescale))
        let audioContext = RDMAudioContext(audioURL: audioURL,
                                           sampleRate: Int(asbd.pointee.mSampleRate),
                                           totalSamples: totalSamples,
                                           channelCount: Int(asbd.pointee.mChannelsPerFrame),
                                           asset: asset,
                                           assetTrack: assetTrack)
        completionHandler(.success(audioContext))
        return

      default:
        NSLog("FDWaveformView could not load asset: \(error?.localizedDescription ?? "Unknown error")")
      }

      if let error = error {
        completionHandler(.failure(RDMAudioError(error.localizedDescription)))
      } else {
        completionHandler(.failure(RDMAudioError("Failed to load the audio track")))
      }
    }
  }
}
