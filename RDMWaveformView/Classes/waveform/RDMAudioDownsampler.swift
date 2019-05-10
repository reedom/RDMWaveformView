//
//  RDMAudioDownsampler.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 4/19/19.
//

import Foundation
import AVFoundation
import SparseRanges

/// `RDMAudioDownsampler` downsamples the audio's original samples.
///
/// The purpose of downsampling is to render a waveform graph.
/// The elements of waveform graph consists of downsampled decibel data.
/// For instance, say we have a downsampler with downsampleRate=160,
/// and we have 320 original sample data. The downsampler calculates and
/// generate two downsample data that each datum is the average of the
/// original each 160 data.
class RDMAudioDownsampler {
  // MARK: - Properties

  /// Current audio context to be used for rendering.
  public let audioContext: RDMAudioContext

  /// Downsample rate.
  public let downsampleRate: Int

  /// Maximum decibel in a audio track.
  ///
  /// `RDMAudioDownsampler` updates this value if it founds more
  /// greater value while downsampling process.
  public private(set) var decibelMax: CGFloat

  /// Minimum decibel in a audio track.
  public let decibelMin: CGFloat

  /// If the audio track duration is shorter than this value,
  /// the `RDMAudioDownsampler` will automatically downsample
  /// entire track.
  public var preloadIfTrackShorterThan: TimeInterval

  // MARK: - Private variables

  /// Records already processed sample ranges.
  private var handledRanges = SparseCountableRange<Int>()
  /// A collection of downsampled data.
  private var downsamples: [CGFloat]
  /// A collection of running `RDMAudioLoadOperation`.
  private var operations = [RDMAudioLoadOperation]()

  typealias Callback = (
    _ downsampleRange: DownsampleRange,
    _ downsamples: ArraySlice<CGFloat>) -> Void

  // MARK: - Initializer

  public init(audioContext: RDMAudioContext,
              downsampleRate: Int,
              decibelMax: CGFloat,
              decibelMin: CGFloat,
              preloadIfTrackShorterThan: TimeInterval = 5*60) {
    self.audioContext = audioContext
    self.downsampleRate = downsampleRate
    self.decibelMax = decibelMax
    self.decibelMin = decibelMin
    self.preloadIfTrackShorterThan = preloadIfTrackShorterThan

    let n = audioContext.totalSamples / downsampleRate + 1
    print("duration: \(audioContext.asset.duration.seconds)")
    print("sampleRate: \(audioContext.sampleRate)")
    print("totalSamples: \(audioContext.totalSamples), downsampleRate: \(downsampleRate)")
    self.downsamples = Array<CGFloat>(repeating: 0, count: n)
  }

  deinit {
    debugPrint("RDMAudioDownsampler.deinit")
  }

  /// MARK: - Operations

  /// Abandon all of downsampled data.
  public func reset() {
    cancel()
    handledRanges.removeAll()
  }

  /// Cancel the currently running downsampling operations.
  public func cancel() {
    operations.forEach { $0.cancel() }
  }

  /// Downsapmle the specific range.
  ///
  /// - Parameter timeRange: Downsample target range in second.
  /// - Parameter onComplete: Called when `RDMAudioDownsampler` completes
  ///             downsampling the entire range.
  /// - Parameter callback: called every times when `RDMAudioDownsampler` makes
  ///             a chunk of downsampling data.
  public func downsample(timeRange: TimeRange,
                         onComplete: @escaping () -> Void,
                         callback: @escaping Callback) {
    let firstCall = downsamples.isEmpty

    let onLocalCompleted = { [weak self] in
      guard let self = self else { return }
      if firstCall {
        if self.audioContext.asset.duration.seconds < self.preloadIfTrackShorterThan {
          self.downsampleAll()
        }
      }
      onComplete()
    }

    let calc = RDMAudioDownsampleCalc(audioContext, downsampleRate)
    let range = calc.downsampleRangeFrom(timeRange: timeRange)
    if let founds = handledRanges.intersects(range) {
      // Downsampled data exist.
      founds.forEach { (downsampleRange) in
        callback(downsampleRange, downsamples[downsampleRange])
      }
    }

    if let notFounds = handledRanges.differentials(range) {
      // It needs to downsample.
      notFounds.forEach { (downsampleRange) in
        let calc = RDMAudioDownsampleCalc(audioContext, downsampleRate)
        let timeRange = calc.timeRangeFrom(downsampleRange: downsampleRange)
        invokeOperation(timeRange, onComplete: onLocalCompleted, callback: callback)
      }
    } else {
      onLocalCompleted()
    }

  }

  /// Start downsampling the entire audio track.
  public func downsampleAll() {
    if let notFounds = handledRanges.differentials(0 ..< audioContext.totalSamples) {
      notFounds.forEach { (samplesRange) in
        invokeOperation(samplesRange, onComplete: {}) { ( _, _ ) in }
      }
    }
  }

  private func invokeOperation(_ timeRange: TimeRange,
                               onComplete: @escaping () -> Void,
                               callback: @escaping Callback) {
    var completed = false
    var taskCount: Int32 = 0
    var called: Int32 = 0

    let operation = RDMAudioLoadOperation(audioContext: audioContext,
                                          timeRange: timeRange,
                                          downsampleRate: downsampleRate,
                                          decibelMax: decibelMax,
                                          decibelMin: decibelMin)
    { [weak self] (operation, downsampleRange, downsamples) -> Void in
      guard let self = self else { return }
      OSAtomicIncrement32(&taskCount)
      DispatchQueue.main.async {
        if self.decibelMax < operation.decibelMax {
          self.decibelMax = operation.decibelMax
        }
        if let downsamples = downsamples {
          self.handledRanges.add(downsampleRange)
          self.store(downsampleRange, downsamples)
        }
        if let i = self.operations.firstIndex(of: operation) {
          self.operations.remove(at: i)
        }
        if let downsamples = downsamples {
          callback(downsampleRange, downsamples[0..<downsamples.count])
        }
        if OSAtomicDecrement32(&taskCount) == 0 && completed {
          if OSAtomicIncrement32(&called) == 1 {
            onComplete()
          }
        }
      }
    }

    operation.completionBlock = { [weak self] in
      guard self != nil else { return }
      completed = true
      if taskCount == 0 {
        if OSAtomicIncrement32(&called) == 1 {
          onComplete()
        }
      }
    }

    operations.append(operation)
    operation.start()
  }

  private func store(_ downsampleRange: DownsampleRange, _ downsamples: [CGFloat]) {
    if self.downsamples.count < downsampleRange.upperBound {
      let count = downsampleRange.upperBound - downsamples.count
      self.downsamples.append(contentsOf: Array<CGFloat>(repeating: 0, count: count))
    }
    for (i, sample) in downsamples.enumerated() {
      self.downsamples[downsampleRange.lowerBound + i] = sample
    }
  }
}
