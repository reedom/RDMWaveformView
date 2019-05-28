//
//  Downsampler.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/20.
//

protocol DownsampledHandler: class {
  func downsamplerDidDownsample(downsampleRange: DownsampleRange, downsamples: ArraySlice<CGFloat>)
}

public class Downsampler: NSObject {
  private let controller: AudioDataController

  /// Maximum decibel in a audio track.
  ///
  /// `AudioDownsampler` updates this value if it founds more
  /// greater value while downsampling process.
  public private(set) var decibelMax: CGFloat = 0

  /// Minimum decibel in a audio track.
  public let decibelMin: CGFloat = -50

  /// Status of the instance.
  public private(set) var status = DownsamplingState.idle

  private var handlers = [HandlerInfo]()

  public init(_ controller: AudioDataController) {
    self.controller = controller
    super.init()
    controller.subscribe(self)
  }

  private var operations = [DownsampleOperation]()
}

extension Downsampler: AudioDataControllerDelegate {
  @objc public func audioDataControllerDidSetAudioContext(_ controller: AudioDataController) {
    handlers.forEach { $0.setUp(controller.audioContext!, decibelMin: decibelMin) }
  }
}

extension Downsampler {
  func addHandler(downsampleRate: Int, handler: DownsampledHandler) {
    addHandler(downsampleRate: downsampleRate,
               timeRange: HandlerInfo.entireTrack,
               handler: handler)
  }

  func addHandler(downsampleRate: Int, timeRange: TimeRange, handler: DownsampledHandler) {
    guard let audioContext = controller.audioContext else { fatalError("needs audioContext")}

    let handlerInfo = handlers.first { $0.downsampleRate == downsampleRate } ?? {
      let handlerInfo = HandlerInfo(downsampleRate)
      handlerInfo.setUp(audioContext, decibelMin: decibelMin)

      if let pos = handlers.firstIndex(where: { downsampleRate < $0.downsampleRate}) {
        handlers.insert(handlerInfo, at: pos)
      } else {
        handlers.append(handlerInfo)
      }
      return handlerInfo
    }()

    let downsampleRange = downsampleRangeFrom(audioContext, downsampleRate, timeRange: timeRange)
    handlerInfo.attach(downsampleRange: downsampleRange, handler: handler)
  }

  func removeHandler(downsampleRate: Int, handler: DownsampledHandler) {
    removeHandler(downsampleRate: downsampleRate,
                  timeRange: HandlerInfo.entireTrack,
                  handler: handler)
  }

  func removeHandler(downsampleRate: Int, timeRange: TimeRange, handler: DownsampledHandler) {
    guard let audioContext = controller.audioContext else { fatalError("needs audioContext")}
    guard let pos = handlers.firstIndex(where: { downsampleRate <= $0.downsampleRate }) else { return }

    let downsampleRange = downsampleRangeFrom(audioContext, downsampleRate, timeRange: timeRange)
    handlers[pos].detach(downsampleRange: downsampleRange, handler: handler)
    if !handlers[pos].hasHandler {
      handlers.remove(at: pos)
    }
  }
}

extension Downsampler {
  public typealias CompletionHandler = (Result<Void, Error>) -> Void

  public func cancel() {
    operations.forEach { $0.cancel() }
  }

  public func startLoading() {
    startLoading(completionHandler: { _ in })
  }

  public func startLoading(completionHandler: @escaping CompletionHandler) {
    guard
      [DownsamplingState.idle, DownsamplingState.failed].contains(status),
      controller.audioContext != nil
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
      let audioContext = controller.audioContext
      else {
        completionHandler(.success(Void()))
        return
    }

    let primaryHandler = handlers.first!
    let timeRange = 0 ..< Int(ceil(audioContext.asset.duration.seconds))
    let operation = DownsampleOperation(audioContext: audioContext,
                                            timeRange: timeRange,
                                            downsampleRate: primaryHandler.downsampleRate,
                                            decibelMax: decibelMax,
                                            decibelMin: decibelMin)
    { [weak self] (operation, downsampleRange, downsamples, lastCall) -> Void in
      guard let self = self else { return }

      if self.decibelMax < operation.decibelMax {
        self.decibelMax = operation.decibelMax
      }
      primaryHandler.append(downsampleRange, downsamples)
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

      DispatchQueue.main.async {
        guard let self = self else { return }
        if let index = self.operations.firstIndex(of: operation) {
          self.operations.remove(at: index)
        }
      }
    }

    operations.append(operation)
    operation.start()
  }
}

extension Downsampler {
  func save() {
    save(completionHandler: { _ in })
  }

  func save(completionHandler: @escaping CompletionHandler) {

  }
}

extension Downsampler {
  // FIXME use NSOperation
  public func findBlankMoments(decibelLessThan: Double,
                               blankMomentLongerThan: TimeInterval,
                               callback: @escaping (TimeInterval, TimeInterval) -> Void) -> Bool {
    guard
      let audioContext = controller.audioContext,
      let primary = handlers.first,
      primary.finished,
      let downsamples = primary.downsamples
      else { return false }

    let notify = { (_ from: TimeInterval, _ to: TimeInterval) in
      DispatchQueue.main.async {
        callback(from, to)
      }
    }

    let downsampleRate = primary.downsampleRate
    DispatchQueue.global().async { [weak self] in
      guard self != nil else { return }
      let secPerSample = 1 / TimeInterval(audioContext.sampleRate) * TimeInterval(downsampleRate)
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
    return true
  }
}

extension Downsampler {
  /// Downsapmle the specific range.
  ///
  /// - Parameter downsampleRate: Downsample rate.
  /// - Parameter timeRange: Downsample target range in second.
  func downsample(downsampleRate: Int, timeRange: TimeRange) -> ArraySlice<CGFloat>? {
    guard let audioContext = controller.audioContext else { return nil }
    let range = downsampleRangeFrom(audioContext, downsampleRate, timeRange: timeRange)
    guard let handler = handlers.first(where: { $0.downsampleRate == downsampleRate }) else { return nil }
    guard range.upperBound <= handler.nextPos else { return nil }
    return handler.downsamples?[range]
  }
}

fileprivate class HandlerInfo {
  static let entireTrack: DownsampleRange = 0..<0

  private let queue = DispatchQueue(label: "com.reedom.waveform.RDMWaveformView.HandlerInfo")

  private class HandlerEntry {
    let downsampleRange: DownsampleRange
    weak var handler: DownsampledHandler?

    init(_ downsampleRange: DownsampleRange, _ handler: DownsampledHandler) {
      self.downsampleRange = downsampleRange
      self.handler = handler
    }
  }

  /// Downsample rate.
  /// A number of samples to generate a downsampled value.
  let downsampleRate: Int
  /// Handler.
  private var handlers = [HandlerEntry]()

  /// Stores downsampled data.
  var downsamples: [CGFloat]?
  /// Index of `downsamples` at where next downsampled data goes.
  var nextPos: Int = 0
  /// Refers the index of the reference handler's `downsamples` where
  /// this handler read data from.
  private var referenceLowerBound: Int = 0
  private var referenceUpperBound: Int = 0

  /// Indicates whether a downsampling has finished.
  var finished = false

  init(_ downsampleRate: Int) {
    self.downsampleRate = downsampleRate
  }

  func attach(downsampleRange: DownsampleRange, handler: DownsampledHandler) {
    queue.sync {
      if !self.handlers.contains(where: { $0.downsampleRange == downsampleRange && $0.handler === handler }) {
        self.handlers.append(HandlerEntry(downsampleRange, handler))
      }
    }
  }

  func detach(downsampleRange: DownsampleRange, handler: DownsampledHandler) {
    queue.sync {
      self.handlers.removeAll(where: { $0.downsampleRange == downsampleRange && $0.handler === handler })
    }
  }

  var hasHandler: Bool {
    return !handlers.isEmpty
  }

  func setUp(_ audioContext: AudioContext, decibelMin: CGFloat) {
    let timeRange = 0 ..< Int(ceil(audioContext.asset.duration.seconds))
    let downsampleCount = Int(Double(timeRange.upperBound) * Double(audioContext.sampleRate) / Double(downsampleRate))
    downsamples = [CGFloat](repeating: decibelMin, count: downsampleCount)
    nextPos = 0
    referenceLowerBound = 0
    referenceUpperBound = 0
    finished = false
  }

  func append(_ downsampleRange: DownsampleRange, _ downsamples: [CGFloat]) {
    guard self.downsamples != nil else { return }

    if self.downsamples!.count < downsampleRange.upperBound {
      let count = downsampleRange.upperBound - downsamples.count
      self.downsamples!.append(contentsOf: Array<CGFloat>(repeating: 0, count: count))
    }
    for (i, sample) in downsamples.enumerated() {
      self.downsamples![downsampleRange.lowerBound + i] = sample
    }
    nextPos = downsampleRange.upperBound
    notify(downsampleRange)
  }

  func downsample(reference: HandlerInfo, lastCall: Bool) {
    guard self.downsamples != nil else { return }

    if referenceUpperBound == 0 {
      referenceUpperBound = calcReferenceUpperBound(reference)
    }

    let startPos = nextPos
    while referenceUpperBound < reference.nextPos || lastCall {
      guard referenceLowerBound < referenceUpperBound else { break }
      downsamples![nextPos] = calcAvg(reference)
      nextPos += 1
      referenceLowerBound = referenceUpperBound
      referenceUpperBound = calcReferenceUpperBound(reference)
    }
    if startPos < nextPos {
      notify(startPos ..< nextPos)
    }
  }

  func notify(_ range: DownsampleRange) {
    queue.async { [weak self] in
      guard let self = self else { return }

      self.handlers.forEach { entry in
        if entry.downsampleRange == HandlerInfo.entireTrack {
          entry.handler?.downsamplerDidDownsample(downsampleRange: range, downsamples: self.downsamples![range])
        } else if entry.downsampleRange.overlaps(range) {
          let downsampleRange = range.clamped(to: entry.downsampleRange)
          entry.handler?.downsamplerDidDownsample(downsampleRange: downsampleRange,
                                                  downsamples: self.downsamples![downsampleRange])
        }
      }
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

