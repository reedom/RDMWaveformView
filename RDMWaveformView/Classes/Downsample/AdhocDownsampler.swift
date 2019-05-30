//
//  AdhocDownsampler.swift
//  WaveformView
//
//  Created by HANAI Tohru on 2019/05/21.
//

import SparseRanges

/// `AdhocDownsampler` downsamples the audio's original samples.
///
/// The purpose of downsampling is to render a waveform graph.
/// The elements of waveform graph consists of downsampled decibel data.
/// For instance, say we have a downsampler with downsampleRate=160,
/// and we have 320 original sample data. The downsampler calculates and
/// generate two downsample data that each datum is the average of the
/// original each 160 data.
class AdhocDownsampler {
  // MARK: - Properties

  /// Current audio context to be used for rendering.
  public let audioContext: AudioContext

  /// Downsample rate.
  public let downsampleRate: Int

  /// Maximum decibel in a audio track.
  ///
  /// `AdhocDownsampler` updates this value if it founds more
  /// greater value while downsampling process.
  public private(set) var decibelMax: CGFloat

  /// Minimum decibel in a audio track.
  public let decibelMin: CGFloat

  // MARK: - Private variables

  private var entireDownsampleRange: CountableRange<Int> {
    let timeRange = 0 ..< Int(ceil(audioContext.asset.duration.seconds))
    return downsampleRangeFrom(audioContext, downsampleRate, timeRange: timeRange)
  }

  /// Records already processed sample ranges.
  private var handledRanges = SparseCountableRange<Int>()
  /// A collection of downsampled data.
  private var downsamples: [CGFloat]
  /// A collection of running `AudioLoadOperation`.
  private var operations = [DownsampleOperation]()

  private var loadedAll = false

  typealias Callback = (
    _ downsampleRange: DownsampleRange,
    _ downsamples: ArraySlice<CGFloat>) -> Void

  typealias OnComplete = () -> Void

  // MARK: - Initializer

  public init(audioContext: AudioContext,
              downsampleRate: Int,
              decibelMax: CGFloat,
              decibelMin: CGFloat) {
    self.audioContext = audioContext
    self.downsampleRate = downsampleRate
    self.decibelMax = decibelMax
    self.decibelMin = decibelMin

    let n = audioContext.totalSamples / downsampleRate + 1
    print("duration: \(audioContext.asset.duration.seconds)")
    print("sampleRate: \(audioContext.sampleRate)")
    print("totalSamples: \(audioContext.totalSamples), downsampleRate: \(downsampleRate)")
    self.downsamples = Array<CGFloat>(repeating: 0, count: n)
  }

  deinit {
    debugPrint("AdhocDownsampler.deinit")
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
  /// - Parameter onComplete: Called when `AdhocDownsampler` completes
  ///             downsampling the entire range.
  /// - Parameter callback: called every times when `AdhocDownsampler` makes
  ///             a chunk of downsampling data.
  public func downsample(timeRange: TimeRange,
                         onComplete: @escaping OnComplete,
                         callback: @escaping Callback) {
    let range = downsampleRangeFrom(audioContext, downsampleRate, timeRange: timeRange)
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
        let timeRange = timeRangeFrom(audioContext, downsampleRate, downsampleRange: downsampleRange)
        invokeOperation(timeRange, onComplete: onComplete, callback: callback)
      }
    } else {
      onComplete()
    }
  }

  private func invokeOperation(_ timeRange: TimeRange,
                               onComplete: @escaping () -> Void,
                               callback: @escaping Callback) {
    var lowerBound: Int?
    var upperBound: Int = 0

    let operation = DownsampleOperation(audioContext: audioContext,
                                        timeRange: timeRange,
                                        downsampleRate: downsampleRate,
                                        decibelMax: decibelMax,
                                        decibelMin: decibelMin)
    { [weak self] (operation, downsampleRange, downsamples, lastCall) -> Void in
      guard let self = self else { return }

      DispatchQueue.main.async {
        if self.decibelMax < operation.decibelMax {
          self.decibelMax = operation.decibelMax
        }
        self.handledRanges.add(downsampleRange)
        self.store(downsampleRange, downsamples)
        if let i = self.operations.firstIndex(of: operation) {
          self.operations.remove(at: i)
        }

        if lowerBound == nil {
          lowerBound = downsampleRange.lowerBound
        }
        if !downsampleRange.isEmpty {
          upperBound = max(upperBound, downsampleRange.upperBound)
        }

        if lastCall {
          if let lowerBound = lowerBound, lowerBound < upperBound {
            let range = lowerBound ..< upperBound
            callback(range, self.downsamples[range])
          }
          if Int(ceil(self.audioContext.asset.duration.seconds)) <= timeRange.upperBound {
            // when it has readed the tail of the track
            if upperBound < self.downsamples.count {
              // self.downsamples has extra elements. Let's drop them.
              // self.handledRanges.subtract(upperBound ..< self.downsamples.count)
              self.downsamples.removeLast(self.downsamples.count - upperBound)
            }
          }
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

