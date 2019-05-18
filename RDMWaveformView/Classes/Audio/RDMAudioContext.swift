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
  /// Load audio track from the specified URL.
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

extension RDMAudioContext {
  /// The type of the block which receives sample data.
  ///
  /// - Parameter sampleData: sample data.
  /// - Returns: `true` to continue iterating, `false` to stop iterating.
  public typealias IterateSampleDataHandler = (_ sampleData: Data) -> Bool

  /// Read the loaded audio track and extract sample data.
  ///
  /// - Parameter duration: the time range to walk through.
  /// - Parameter unitLength: The data length that `sampleDataHandler` receives at a time.
  ///                         But on the last iteration the data might be shorter.
  /// - Parameter sampleDataHandler: A handler to receive sample data repitively.
  public func iterateSampleData(duration: CMTimeRange, unitLength: Int, sampleDataHandler: @escaping IterateSampleDataHandler) {
    guard
      let reader = try? AVAssetReader(asset: asset),
      0 < unitLength
      else { return }

    let outputSettingsDict: [String : Any] = [
      AVFormatIDKey: Int(kAudioFormatLinearPCM),
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsNonInterleaved: false
    ]

    let readerOutput = AVAssetReaderTrackOutput(track: assetTrack, outputSettings: outputSettingsDict)
    readerOutput.alwaysCopiesSampleData = false
    reader.add(readerOutput)

    // 16-bit samples
    reader.timeRange = duration
    reader.startReading()
    defer { reader.cancelReading() } // Cancel reading if we exit early if operation is cancelled

    var cancelled = false
    let sampleBuffer = BufferIterationHelper(bufferSize: unitLength) { cancelled = !sampleDataHandler($0) }

    var remainBytes = Int(ceil(duration.duration.seconds * Double(sampleRate))) * channelCount * MemoryLayout<Int16>.size
    while reader.status == .reading {
      guard !cancelled, 0 < remainBytes else { return }

      guard
        let readSampleBuffer = readerOutput.copyNextSampleBuffer(),
        let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer)
        else { break }

      // Append audio sample buffer into our current sample buffer
      var readBufferLength = 0
      var readBufferPointer: UnsafeMutablePointer<Int8>?
      CMBlockBufferGetDataPointer(readBuffer,
                                  atOffset: 0,
                                  lengthAtOffsetOut: &readBufferLength,
                                  totalLengthOut: nil,
                                  dataPointerOut: &readBufferPointer)
      let appendLength = min(readBufferLength, remainBytes)
      remainBytes -= appendLength
      sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: appendLength))
      CMSampleBufferInvalidate(readSampleBuffer)
    }

    sampleBuffer.flush()

    // if (reader.status == AVAssetReaderStatusFailed || reader.status == AVAssetReaderStatusUnknown)
    // Something went wrong. Handle it, or not depending on if you can get above to work
    if reader.status != .completed {
      NSLog("RDMWaveformRenderOperation ends not in completed state: \(String(describing: reader.error))")
    }
  }
}

class BufferIterationHelper {
  typealias ChunkHandler = (_ data: Data) -> Void
  private(set) var pos: Int = 0
  private(set) var buffer: Data
  private let chunkHandler: ChunkHandler

  init(bufferSize: Int, chunkHandler: @escaping ChunkHandler) {
    self.buffer = Data(count: bufferSize)
    self.chunkHandler = chunkHandler
  }

  func append<E>(_ data: UnsafeBufferPointer<E>) {
    let remaining = buffer.count - pos
    if data.count < remaining {
      buffer.replaceSubrange(pos..<pos+data.count, with: data)
      pos += data.count
      return
    }

    let chunk = UnsafeBufferPointer(rebasing: data[0..<remaining])
    buffer.replaceSubrange(pos..<buffer.count, with: chunk)
    pos = 0
    chunkHandler(buffer)

    if remaining < data.count {
      let chunk = UnsafeBufferPointer(rebasing: data[remaining..<data.count])
      append(chunk)
    }
  }

  func flush() {
    if 0 < pos {
      let len = pos
      pos = 0
      chunkHandler(buffer[0..<len])
    }
  }
}
