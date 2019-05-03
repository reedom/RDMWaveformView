//
//  RDMDownsampler.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 4/19/19.
//

import Foundation
import AVFoundation
import SparseRanges

class RDMAudioDownsampler {
  // MARK: - Properties

  /// Current audio context to be used for rendering
  public let audioContext: RDMAudioContext

  /// Downsample rate. `RDMDownsampler` turns the number of `downsampleRate` samples
  /// into a sample.
  public let downsampleRate: Int

  private var _decibelMax: CGFloat
  public var decibelMax: CGFloat {
    return _decibelMax
  }
  public let decibelMin: CGFloat

  // MARK: - Private helper properties

  // MARK: - Private variables

  private var handledRanges = SparseCountableRange<Int>()
  private var downsamples: [CGFloat]
  private var operations = [RDMAudioLoadOperation]()

  typealias Callback = (_ samplesRange: CountableRange<Int>, _ downsamples: ArraySlice<CGFloat>) -> Void

  // MARK: - Initializer

  public init(audioContext: RDMAudioContext,
              downsampleRate: Int,
              decibelMax: CGFloat,
              decibelMin: CGFloat) {
    self.audioContext = audioContext
    self.downsampleRate = downsampleRate
    self._decibelMax = decibelMax
    self.decibelMin = decibelMin

    let n = audioContext.totalSamples / downsampleRate + 1
    self.downsamples = Array<CGFloat>(repeating: 0, count: n)
  }

  public func reset() {
    cancel()
    handledRanges.removeAll()
  }

  public func cancel() {
    operations.forEach { $0.cancel() }
  }

  public func downsample(samplesRange: CountableRange<Int>,
                         onComplete: @escaping () -> Void,
                         callback: @escaping Callback) {
    if let gaps = handledRanges.gaps(samplesRange) {
      gaps.forEach { (samplesRange) in
        invokeOperation(samplesRange, onComplete: onComplete, callback: callback)
      }
    } else {
      callback(samplesRange, getDownsamples(samplesRange))
    }
  }

  public func downsampleAll() {
    if let gaps = handledRanges.gaps(0 ..< audioContext.totalSamples) {
      gaps.forEach { (samplesRange) in
        invokeOperation(samplesRange, onComplete: {}) { ( _, _ ) in }
      }
    }
  }

  private func invokeOperation(_ samplesRange: CountableRange<Int>,
                               onComplete: @escaping () -> Void,
                               callback: @escaping Callback) {
    let operation = RDMAudioLoadOperation(audioContext: audioContext,
                                          samplesRange: samplesRange,
                                          downsampleRate: downsampleRate,
                                          decibelMin: decibelMin,
                                          decibelMax: decibelMax)
    { [weak self] (operation, chunkRange, downsamples) -> Void in
      guard let self = self else { return }
      if let downsamples = downsamples {
        self.handledRanges.add(chunkRange)
        self.store(chunkRange.lowerBound / self.downsampleRate, downsamples)
      }
      DispatchQueue.main.async {
        if let i = self.operations.firstIndex(of: operation) {
          self.operations.remove(at: i)
        }
        if let downsamples = downsamples {
          callback(chunkRange, downsamples[0..<downsamples.count])
        }
      }
    }

    operation.completionBlock = onComplete
    operations.append(operation)
    operation.start()
  }

  private func store(_ downsampleIndex: Int, _ downsamples: [CGFloat]) {
    for (i, sample) in downsamples.enumerated() {
      self.downsamples[downsampleIndex + i] = sample
    }
  }

  private func getIndex(for samplePosition: Int) -> Int {
    return max(0, min(samplePosition, audioContext.totalSamples) / downsampleRate)
  }

  private func getDownsamples(_ samplesRange: CountableRange<Int>) -> ArraySlice<CGFloat> {
    let start = getIndex(for: samplesRange.lowerBound)
    let end = getIndex(for: samplesRange.upperBound)
    return downsamples[start ..< end]
  }
}
