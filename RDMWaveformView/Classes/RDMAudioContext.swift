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

  public let sampleRate: Int

  /// Total number of samples in loaded asset
  public let totalSamples: Int

  public let channelCount: Int

  /// Loaded asset
  public let asset: AVAsset

  // Loaded assetTrack
  public let assetTrack: AVAssetTrack
}

extension RDMAudioContext {
  public static func load(fromAudioURL audioURL: URL, completionHandler: @escaping (_ audioContext: RDMAudioContext?) -> ()) {
    let asset = AVURLAsset(url: audioURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: NSNumber(value: true)])

    guard let assetTrack = asset.tracks(withMediaType: AVMediaType.audio).first else {
      print("FDWaveformView failed to load AVAssetTrack")
      completionHandler(nil)
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
        print("totalSamples: \(totalSamples)")
        let audioContext = RDMAudioContext(audioURL: audioURL,
                                           sampleRate: Int(asbd.pointee.mSampleRate),
                                           totalSamples: totalSamples,
                                           channelCount: Int(asbd.pointee.mChannelsPerFrame),
                                           asset: asset,
                                           assetTrack: assetTrack)
        completionHandler(audioContext)
        return

      default:
        print("FDWaveformView could not load asset: \(error?.localizedDescription ?? "Unknown error")")
      }

      completionHandler(nil)
    }
  }
}
