//
//  RDMAudioDownsampleManager.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/18.
//

import Foundation
import AVFoundation
import SparseRanges

public class RDMAudioDownsampleManager {
  /// Audio information.
  public var audioContext: AudioContext? {
    didSet {
      if let audioContext = audioContext {
        handlers.forEach { $0.setUp(audioContext, decibelMin: decibelMin) }
      }
    }
  }

  /// Maximum decibel in a audio track.
  ///
  /// `RDMAudioDownsampler` updates this value if it founds more
  /// greater value while downsampling process.
  public private(set) var decibelMax: CGFloat

  /// Minimum decibel in a audio track.
  public let decibelMin: CGFloat

  public enum Status {
    case idle
    case loading
    case loaded
    case failed
  }

  /// Status of the instance.
  public private(set) var status = Status.idle

  private var handlers = [HandlerInfo]()
  private var operation: RDMAudioDownsampleOperation?

  public typealias DownsampledHandler = (_ downsampleRange: DownsampleRange, _ downsamples: ArraySlice<CGFloat>) -> Void

  public init(decibelMax: CGFloat, decibelMin: CGFloat) {
    self.decibelMax = decibelMax
    self.decibelMin = decibelMin
  }

  public func addHandler(downsampleRate: Int, handler: @escaping DownsampledHandler) {
    let handlerInfo = HandlerInfo(downsampleRate, handler)
    if let audioContext = audioContext {
      handlerInfo.setUp(audioContext, decibelMin: decibelMin)
    }

    if let pos = handlers.firstIndex(where: { downsampleRate < $0.downsampleRate }) {
      handlers.insert(handlerInfo, at: pos)
    } else {
      handlers.append(handlerInfo)
    }
  }
}

extension RDMAudioDownsampleManager {
  public typealias CompletionHandler = (Result<Void, Error>) -> Void

  public func load() {
    load(completionHandler: { _ in })
  }

  public func load(completionHandler: @escaping CompletionHandler) {
    guard
      [Status.idle, Status.failed].contains(status),
      audioContext != nil
      else { return }

    self.status = .loading

    loadFromCache() { [weak self] result in
      switch result {
      case .success(_):
        self?.status = .loaded
        completionHandler(result)
        return
      case .failure(_):
        break
      }

      self?.loadFromAudio() { result in
        switch result {
        case .success(_):
          self?.status = .loaded
        case .failure(let error):
          self?.status = .failed
          print(error)
        }
        completionHandler(result)
      }
    }
  }

  private class NotFoundError: Error {
  }

  private func loadFromCache(completionHandler: @escaping CompletionHandler) {
    completionHandler(.failure(NotFoundError()))
  }

  private func loadFromAudio(completionHandler: @escaping CompletionHandler) {
    guard
      !handlers.isEmpty,
      !handlers.allSatisfy({ $0.finished }),
      let audioContext = audioContext
      else {
        completionHandler(.success(Void()))
        return
    }

    let primaryHandler = handlers.first!
    let timeRange = 0 ..< Int(ceil(audioContext.asset.duration.seconds))
    let operation = RDMAudioDownsampleOperation(audioContext: audioContext,
                                                timeRange: timeRange,
                                                downsampleRate: primaryHandler.downsampleRate,
                                                decibelMax: decibelMax,
                                                decibelMin: decibelMin)
    { [weak self] (operation, downsampleRange, downsamples, lastCall) -> Void in
      guard let self = self else { return }

      if self.decibelMax < operation.decibelMax {
        self.decibelMax = operation.decibelMax
      }
      primaryHandler.store(downsampleRange, downsamples)
      primaryHandler.nextPos = downsampleRange.upperBound
      primaryHandler.handler(downsampleRange, downsamples[downsamples.startIndex..<downsamples.endIndex])

      for i in 1 ..< self.handlers.count {
        self.handlers[i].downsample(reference: primaryHandler, lastCall: lastCall)
      }
    }

    operation.completionBlock = { [weak self] in
      guard
        self != nil,
        primaryHandler.downsamples != nil
        else { return }

      if primaryHandler.nextPos < primaryHandler.downsamples!.count {
        // self.downsamples has extra elements. Let's drop them.
        // self.handledRanges.subtract(upperBound ..< self.downsamples.count)
        primaryHandler.downsamples!.removeLast(primaryHandler.downsamples!.count - primaryHandler.nextPos)
      }

      primaryHandler.finished = true
      completionHandler(.success(Void()))
    }

    self.operation = operation
    operation.start()
  }
}

extension RDMAudioDownsampleManager {
  public func save() {

  }
}

extension RDMAudioDownsampleManager {
  /// Downsapmle the specific range.
  ///
  /// - Parameter timeRange: Downsample target range in second.
  /// - Parameter downsampleRate: Downsample rate.
  public func downsample(timeRange: TimeRange, downsampleRate: Int) -> ArraySlice<CGFloat>? {
    guard let audioContext = audioContext else { return nil }
    let calc = RDMAudioDownsampleCalc(audioContext, downsampleRate)
    let range = calc.downsampleRangeFrom(timeRange: timeRange)
    guard let handler = handlers.first(where: { $0.downsampleRate == downsampleRate }) else { return nil }
    guard range.upperBound <= handler.nextPos else { return nil }
    return handler.downsamples?[range]
  }
}

fileprivate class HandlerInfo {
  typealias DownsampledHandler = RDMAudioDownsampleManager.DownsampledHandler

  /// Downsample rate.
  /// A number of samples to generate a downsampled value.
  let downsampleRate: Int
  /// Handler.
  let handler: DownsampledHandler

  /// Stores downsampled data.
  var downsamples: [CGFloat]?
  /// Index of `downsamples` at where next downsampled data goes.
  var nextPos: Int = 0
  /// Refers the index of the reference handler's `downsamples` where
  /// this handler read data from.
  var referenceLowerBound: Int = 0
  var referenceUpperBound: Int = 0

  /// Indicates whether a downsampling has finished.
  var finished = false

  init(_ downsampleRate: Int, _ handler: @escaping DownsampledHandler) {
    self.downsampleRate = downsampleRate
    self.handler = handler
  }

  func setUp(_ audioContext: AudioContext, decibelMin: CGFloat) {
    let timeRange = 0 ..< Int(ceil(audioContext.asset.duration.seconds))
    let downsampleCount = Int(Double(timeRange.upperBound) * Double(audioContext.sampleRate) / Double(downsampleRate))
    downsamples = [CGFloat](repeating: decibelMin, count: downsampleCount)
    nextPos = 0
    referenceLowerBound = 0
    referenceUpperBound = 0
  }

  func store(_ downsampleRange: DownsampleRange, _ downsamples: [CGFloat]) {
    guard self.downsamples != nil else { return }

    if self.downsamples!.count < downsampleRange.upperBound {
      let count = downsampleRange.upperBound - downsamples.count
      self.downsamples!.append(contentsOf: Array<CGFloat>(repeating: 0, count: count))
    }
    for (i, sample) in downsamples.enumerated() {
      self.downsamples![downsampleRange.lowerBound + i] = sample
    }
  }

  func downsample(reference: HandlerInfo, lastCall: Bool) {
    guard self.downsamples != nil else { return }

    if referenceUpperBound == 0 {
      referenceUpperBound = calcReferenceUpperBound(reference)
    }

    while referenceUpperBound < reference.nextPos || lastCall {
      guard referenceLowerBound < referenceUpperBound else { return }
      downsamples![nextPos] = calcAvg(reference)
      let range = nextPos ..< nextPos + 1
      handler(range, downsamples![range])
      nextPos += 1
      referenceLowerBound = referenceUpperBound
      referenceUpperBound = calcReferenceUpperBound(reference)
    }
  }

  private func calcReferenceUpperBound(_ reference: HandlerInfo) -> Int {
    let upperBound = Int(ceil(Float((nextPos + 1) * downsampleRate) / Float(reference.downsampleRate)))
    return min(reference.downsamples!.count, max(upperBound, referenceLowerBound + 1))
  }

  private func calcAvg(_ reference: HandlerInfo) -> CGFloat {
    var total: CGFloat = 0
    for i in referenceLowerBound ..< referenceUpperBound {
      total += reference.downsamples![i]
    }

    let n = referenceUpperBound - referenceLowerBound
    return total / CGFloat(n)
  }
}

