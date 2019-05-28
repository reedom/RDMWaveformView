//
// Copyright 2013 - 2017, William Entriken and the RDMWaveformView contributors.
// Copyright 2019, HANAI Tohru.
//
import UIKit
import AVFoundation
import Accelerate

/// Operation used for rendering waveform images
final public class DownsampleOperation: Operation {
  public enum OperationState {
    case idle
    case executing
    case finished
    case cancelled
  }

  /// Holds audio information used for building waveforms.
  public let audioContext: AudioContext
  /// Range of time in seconds.
  /// `RDMAudioLoadOperation` loads and downsamples only the specified range.
  public let timeRange: TimeRange
  /// Downsample rate.
  /// `RDMAudioLoadOperation` uses the specified number of samples to generate
  /// a downsampled value.
  public let downsampleRate: Int
  /// Maximum decibel.
  /// `RDMAudioLoadOperation` may update this value if it finds higher value.
  public private(set) var decibelMax: CGFloat
  /// Minimum decibel.
  /// For samples below the value `RDMAudioLoadOperation` determins as "silent".
  public let decibelMin: CGFloat
  /// Operation state.
  public private(set) var state: OperationState = .idle

  // MARK: - NSOperation Overrides

  public override var isAsynchronous: Bool { return true }
  public override var isExecuting: Bool { return state == .executing }
  public override var isFinished: Bool { return state == .finished }

  public typealias Callback = (
    _ operation: DownsampleOperation,
    _ downsampleRange: DownsampleRange,
    _ downsamples: [CGFloat],
    _ lastCall: Bool) -> Void

  // MARK: - Private

  ///  Handler called when the rendering has completed. nil UIImage indicates that there was an error during processing.
  private let callback: Callback

  /// MARK: - Initialization

  init(audioContext: AudioContext,
       timeRange: TimeRange,
       downsampleRate: Int,
       decibelMax: CGFloat,
       decibelMin: CGFloat,
       callback: @escaping Callback) {
    self.audioContext = audioContext
    self.timeRange = timeRange
    self.downsampleRate = downsampleRate
    self.decibelMin = decibelMin
    self.decibelMax = decibelMax
    self.callback = callback

    super.init()
  }

  /// MARK: - Operation

  public override func start() {
    guard state == .idle else { return }

    willChangeValue(forKey: "isExecuting")
    state = .executing
    didChangeValue(forKey: "isExecuting")

    if #available(iOS 8.0, *) {
      DispatchQueue.global(qos: .background).async {
        self.process()
        self.finish()
      }
    } else {
      DispatchQueue.global(priority: .background).async {
        self.process()
        self.finish()
      }
    }
  }

  private func finish() {
    guard state == .executing else { return }

    // completionBlock called automatically by NSOperation after these values change
    willChangeValue(forKey: "isExecuting")
    willChangeValue(forKey: "isFinished")
    state = .finished
    didChangeValue(forKey: "isExecuting")
    didChangeValue(forKey: "isFinished")
  }

  /// Read the asset and create create a lower resolution set of samples
  private func process() {
    guard
      !isCancelled,
      !timeRange.isEmpty,
      0 < downsampleRate
      else { return }

    let duration = CMTimeRange(start: CMTimeMakeWithSeconds(Float64(timeRange.lowerBound), preferredTimescale: 1000),
                               duration: CMTimeMakeWithSeconds(Float64(timeRange.count), preferredTimescale: 1000))

    let downsampleUnit = audioContext.channelCount * downsampleRate
    let readUnit = downsampleUnit * MemoryLayout<Int16>.size
    let filter = [Float](repeating: 1.0 / Float(downsampleUnit), count: downsampleUnit)

    var downsampleIndex = downsampleRangeFrom(audioContext, downsampleRate, timeRange: timeRange).lowerBound
    audioContext.iterateSampleData(duration: duration, unitLength: readUnit) { [weak self] (sampleBuffer, lastCall) in
      guard let self = self else { return false }
      guard 0 < sampleBuffer.count else {
        self.callback(self, 0..<0, [CGFloat](), lastCall)
        return !self.isCancelled
      }

      let downsampleCount = (readUnit <= sampleBuffer.count) ? sampleBuffer.count / readUnit : 1
      let downsampleRate  = (readUnit <= sampleBuffer.count) ? downsampleUnit : sampleBuffer.count / MemoryLayout<Int16>.size
      let downsamples = self.downsample(fromData: sampleBuffer,
                                        downsampleCount: downsampleCount,
                                        downsampleRate: downsampleRate,
                                        filter: filter)
      let downsampleRange = downsampleIndex ..< downsampleIndex + downsamples.count
      self.callback(self, downsampleRange, downsamples, lastCall)
      downsampleIndex += downsamples.count
      return !self.isCancelled
    }
  }

  private func downsample(fromData sampleBuffer: Data,
                          downsampleCount: Int,
                          downsampleRate: Int,
                          filter: [Float]) -> [CGFloat] {
    let samples = sampleBuffer.withUnsafeBytes {
      $0.baseAddress!.assumingMemoryBound(to: Int16.self)
    }
    let sampleCount = sampleBuffer.count / MemoryLayout<Int16>.size
    var processingBuffer = [Float](repeating: 0.0, count: sampleCount)

    // Convert 16bit int samples to floats
    vDSP_vflt16(samples, 1, &processingBuffer, 1, vDSP_Length(sampleCount))

    // Take the absolute values to get amplitude
    vDSP_vabs(processingBuffer, 1, &processingBuffer, 1, vDSP_Length(sampleCount))

    // Convert samples to a log scale
    var zero: Float = 32768.0
    vDSP_vdbcon(processingBuffer, 1, &zero, &processingBuffer, 1, vDSP_Length(sampleCount), 1)

    // Clip to [noiseFloor, 0]
    var ceil: Float = 0.0
    var noiseFloorFloat = Float(decibelMin)
    vDSP_vclip(processingBuffer, 1, &noiseFloorFloat, &ceil, &processingBuffer, 1, vDSP_Length(sampleCount))

    // Downsample and average
    var downsampledData = [Float](repeating: 0.0, count: downsampleCount)
    vDSP_desamp(processingBuffer,
                vDSP_Stride(downsampleRate),
                filter,
                &downsampledData,
                vDSP_Length(downsampleCount),
                vDSP_Length(downsampleRate))

    let result = downsampledData.map { (value: Float) -> CGFloat in
      let element = CGFloat(value)
      if decibelMax < element {
        decibelMax = element
      }
      return element
    }

    return result
  }
}

