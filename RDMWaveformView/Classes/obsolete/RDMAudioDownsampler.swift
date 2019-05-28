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
  public let audioContext: AudioContext

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

  private var entireDownsampleRange: CountableRange<Int> {
    let calc = RDMAudioDownsampleCalc(audioContext, downsampleRate)
    let timeRange = 0 ..< Int(ceil(audioContext.asset.duration.seconds))
    return calc.downsampleRangeFrom(timeRange: timeRange)
  }

  /// Records already processed sample ranges.
  private var handledRanges = SparseCountableRange<Int>()
  /// A collection of downsampled data.
  private var downsamples: [CGFloat]
  /// A collection of running `RDMAudioLoadOperation`.
  private var operations = [RDMAudioDownsampleOperation]()

  private var loadedAll = false

  typealias Callback = (
    _ downsampleRange: DownsampleRange,
    _ downsamples: ArraySlice<CGFloat>) -> Void

  typealias OnComplete = () -> Void

  // MARK: - Initializer

  public init(audioContext: AudioContext,
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

  public func cancel(outOf timeRange: TimeRange) {
    var cancelled = false
    operations.forEach { operation in
      if !timeRange.overlaps(operation.timeRange) {
        cancelled = true
        operation.cancel()
      }
    }
    if cancelled {
      operations.removeAll { !timeRange.overlaps($0.timeRange) }
    }
  }

  /// Downsapmle the specific range.
  ///
  /// - Parameter timeRange: Downsample target range in second.
  /// - Parameter onComplete: Called when `RDMAudioDownsampler` completes
  ///             downsampling the entire range.
  /// - Parameter callback: called every times when `RDMAudioDownsampler` makes
  ///             a chunk of downsampling data.
  public func downsample(timeRange: TimeRange,
                         onComplete: @escaping OnComplete,
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
      let emptySamples = Array<CGFloat>(repeating: decibelMin,
                                        count: notFounds.max(by: { $0.count < $1.count })!.count)
      // It needs to downsample.
      notFounds.forEach { (downsampleRange) in
        // Call callback so that view can have a change to erase the view area.
        callback(downsampleRange, emptySamples[0..<0])
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
    downsampleAll(onComplete: {})
  }

  /// Start downsampling the entire audio track.
  public func downsampleAll(onComplete: @escaping OnComplete) {
    guard !loadedAll, let notFounds = handledRanges.differentials(entireDownsampleRange) else {
      onComplete()
      return
    }
    var tasks: Int32 = 0

    let completed = { [weak self] in
      guard let self = self else { return }
      if OSAtomicDecrement32(&tasks) == 0 {
        self.loadedAll = true
        onComplete()
      }
    }

    let calc = RDMAudioDownsampleCalc(audioContext, downsampleRate)
    notFounds.forEach { (downsampleRange) in
      OSAtomicIncrement32(&tasks)
      let timeRange = calc.timeRangeFrom(downsampleRange: downsampleRange)
      invokeOperation(timeRange, onComplete:completed) { ( _, _ ) in }
    }
  }

  // FIXME use NSOperation
  public func findBlankMoments(decibelLessThan: Double,
                               blankMomentLongerThan: TimeInterval,
                               callback: @escaping (TimeInterval, TimeInterval) -> Void) {
    if !loadedAll && handledRanges.differentials(entireDownsampleRange) != nil {
      downsampleAll { [weak self] in
        guard let self = self else { return }
        self.findBlankMoments(decibelLessThan: decibelLessThan,
                              blankMomentLongerThan: blankMomentLongerThan,
                              callback: callback)
      }
      return
    }

    let notify = { (_ from: TimeInterval, _ to: TimeInterval) in
      DispatchQueue.main.async {
        callback(from, to)
      }
    }

    let audioContext = self.audioContext
    let downsampleRate = self.downsampleRate
    let downsamples = self.downsamples
    DispatchQueue.global().async { [weak self] in
      guard self != nil else { return }
      let calc = RDMAudioDownsampleCalc(audioContext, downsampleRate)
      let secPerSample = 1 / TimeInterval(audioContext.sampleRate) * TimeInterval(calc.downsampleRate)
      print("secPerSample = \(secPerSample)")

      let minLevel = CGFloat(decibelLessThan)

      var currentTime: TimeInterval = 0
      var muteStart: TimeInterval?
      var muteDuration: TimeInterval = 0

      for decibel in downsamples {
        // print("\(currentTime): decibel=\(decibel), mute=\(muteDuration)")
        if decibel < minLevel {
          if muteStart == nil {
            muteStart = currentTime
          }
          muteDuration += secPerSample
          currentTime += secPerSample
          continue
        }

        if let muteStart = muteStart, blankMomentLongerThan < muteDuration {
          notify(muteStart, muteStart + muteDuration)
        }
        currentTime += secPerSample
        muteStart = nil
        muteDuration = 0
      }

      if let muteStart = muteStart, blankMomentLongerThan < muteDuration {
        notify(muteStart, muteStart + muteDuration)
      }
    }
  }

  private func invokeOperation(_ timeRange: TimeRange,
                               onComplete: @escaping () -> Void,
                               callback: @escaping Callback) {
//    var completed = false
//    var taskCount: Int32 = 0
//    var called: Int32 = 0
    var upperBound: Int = 0

    let operation = RDMAudioDownsampleOperation(audioContext: audioContext,
                                          timeRange: timeRange,
                                          downsampleRate: downsampleRate,
                                          decibelMax: decibelMax,
                                          decibelMin: decibelMin)
    { [weak self] (operation, downsampleRange, downsamples, lastCall) -> Void in
      guard let self = self else { return }
//      OSAtomicIncrement32(&taskCount)
      DispatchQueue.main.async {
        if self.decibelMax < operation.decibelMax {
          self.decibelMax = operation.decibelMax
        }
        self.handledRanges.add(downsampleRange)
        self.store(downsampleRange, downsamples)
        if let i = self.operations.firstIndex(of: operation) {
          self.operations.remove(at: i)
        }
        callback(downsampleRange, downsamples[0..<downsamples.count])
        upperBound = max(upperBound, downsampleRange.upperBound)
        // FIXME comment the purpose of the following logic.
//        if OSAtomicDecrement32(&taskCount) == 0 && completed {
//          if OSAtomicIncrement32(&called) == 1 {
//            onComplete()
//          }
//        }
      }
    }

    operation.completionBlock = { [weak self] in
      guard let self = self else { return }

      DispatchQueue.main.async {
        if Int(ceil(self.audioContext.asset.duration.seconds)) <= timeRange.upperBound {
          // when it has readed the tail of the track
          if upperBound < self.downsamples.count {
            // self.downsamples has extra elements. Let's drop them.
            // self.handledRanges.subtract(upperBound ..< self.downsamples.count)
            self.downsamples.removeLast(self.downsamples.count - upperBound)
          }
        }

//        completed = true
//        if taskCount == 0 {
//          if OSAtomicIncrement32(&called) == 1 {
//            DispatchQueue.main.async {
              onComplete()
//            }
//          }
//        }
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
