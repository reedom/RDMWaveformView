//
// Copyright 2013 - 2017, William Entriken and the RDMWaveformView contributors.
//
import UIKit
import AVFoundation
import Accelerate

/// Operation used for rendering waveform images
final public class RDMAudioLoadOperation: Operation {
  public enum OperationState {
    case idle
    case executing
    case finished
    case cancelled
  }

  /// Current audio context to be used for rendering
  public let audioContext: RDMAudioContext
  public let samplesRange: CountableRange<Int>
  public let downsampleRate: Int
  public let decibelMin: CGFloat
  public var decibelMax: CGFloat

  // MARK: - NSOperation Overrides

  public override var isAsynchronous: Bool { return true }

  private var _state = OperationState.idle
  public var state: OperationState {
    get { return _state }
  }

  public override var isExecuting: Bool { return _state == .executing }
  public override var isFinished: Bool { return _state == .finished }

  public typealias Callback = (
    _ operation: RDMAudioLoadOperation,
    _ chunkRange: CountableRange<Int>,
    _ downsamples: [CGFloat]?) -> Void

  // MARK: - Private

  ///  Handler called when the rendering has completed. nil UIImage indicates that there was an error during processing.
  private let callback: Callback

  /// Final rendered image. Used to hold image for completionHandler.
  private var downsamples: [CGFloat]?

  init(audioContext: RDMAudioContext,
       samplesRange: CountableRange<Int>,
       downsampleRate: Int,
       decibelMin: CGFloat,
       decibelMax: CGFloat,
       callback: @escaping Callback) {
    self.audioContext = audioContext
    self.samplesRange = samplesRange
    self.downsampleRate = downsampleRate
    self.decibelMin = decibelMin
    self.decibelMax = decibelMax
    self.callback = callback

    super.init()
  }

  public override func start() {
    guard _state == .idle else { return }

    willChangeValue(forKey: "isExecuting")
    _state = .executing
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
    guard _state == .executing else { return }

    // completionBlock called automatically by NSOperation after these values change
    willChangeValue(forKey: "isExecuting")
    willChangeValue(forKey: "isFinished")
    _state = .finished
    didChangeValue(forKey: "isExecuting")
    didChangeValue(forKey: "isFinished")
  }

  /// Read the asset and create create a lower resolution set of samples
  private func process() {
    guard
      !isCancelled,
      !samplesRange.isEmpty,
      0 < downsampleRate,
      let reader = try? AVAssetReader(asset: audioContext.asset)
    else { return }

    let duration = audioContext.asset.duration
    reader.timeRange = CMTimeRange(start: CMTime(value: Int64(samplesRange.lowerBound), timescale: duration.timescale),
                                   duration: CMTime(value: Int64(samplesRange.count), timescale: duration.timescale))
    let outputSettingsDict: [String : Any] = [
      AVFormatIDKey: Int(kAudioFormatLinearPCM),
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsNonInterleaved: false
    ]

    let readerOutput = AVAssetReaderTrackOutput(track: audioContext.assetTrack, outputSettings: outputSettingsDict)
    readerOutput.alwaysCopiesSampleData = false
    reader.add(readerOutput)

    let sampleCountInUnit = audioContext.channelCount * downsampleRate
    let filter = [Float](repeating: 1.0 / Float(sampleCountInUnit), count: sampleCountInUnit)

    var outputSamples = [CGFloat]()
    var sampleBuffer = Data()
    var position = samplesRange.lowerBound

    // 16-bit samples
    reader.startReading()
    defer { reader.cancelReading() } // Cancel reading if we exit early if operation is cancelled

    var downsampleIndex = 0
    while reader.status == .reading {
      guard !isCancelled else { return }

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
      sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
      CMSampleBufferInvalidate(readSampleBuffer)

      let samplesCount = sampleBuffer.count / MemoryLayout<Int16>.size
      let downsampleCount = samplesCount / sampleCountInUnit

      guard 0 < samplesCount else { continue }

      let downsamples = downsample(fromData: &sampleBuffer,
                                   samplesCount: samplesCount,
                                   downsampleCount: downsampleCount,
                                   downsampleRate: sampleCountInUnit,
                                   filter: filter)
      let chunkFrom = samplesRange.lowerBound + (downsampleIndex * downsampleRate)
      let chunkTo = samplesRange.lowerBound + ((downsampleIndex + downsampleCount)  * downsampleRate)
      self.callback(self, chunkFrom ..< chunkTo, downsamples)
      downsampleIndex += downsampleCount
    }
    guard !isCancelled else { return }

    if 0 < sampleBuffer.count {
      print("there are remaining samples but just ignore it since they are too small to process")
    }

    // if (reader.status == AVAssetReaderStatusFailed || reader.status == AVAssetReaderStatusUnknown)
    // Something went wrong. Handle it, or not depending on if you can get above to work
    if reader.status != .completed {
      NSLog("RDMWaveformRenderOperation ends not in completed state: \(String(describing: reader.error))")
    }
  }

  private func downsample(fromData sampleBuffer: inout Data,
                          samplesCount: Int,
                          downsampleCount: Int,
                          downsampleRate: Int,
                          filter: [Float]) -> [CGFloat] {
    var result = [CGFloat]()
    let samples = sampleBuffer.withUnsafeBytes {
      $0.baseAddress!.assumingMemoryBound(to: Int16.self)
    }
    var processingBuffer = [Float](repeating: 0.0, count: samplesCount)

    // Convert 16bit int samples to floats
    vDSP_vflt16(samples, 1, &processingBuffer, 1, vDSP_Length(samplesCount))

    // Take the absolute values to get amplitude
    vDSP_vabs(processingBuffer, 1, &processingBuffer, 1, vDSP_Length(samplesCount))

    // Convert samples to a log scale
    var zero: Float = 32768.0
    vDSP_vdbcon(processingBuffer, 1, &zero, &processingBuffer, 1, vDSP_Length(processingBuffer.count), 1)

    // Clip to [noiseFloor, 0]
    var ceil: Float = 0.0
    var noiseFloorFloat = Float(decibelMin)
    vDSP_vclip(processingBuffer, 1, &noiseFloorFloat, &ceil, &processingBuffer, 1, vDSP_Length(processingBuffer.count))

    // Downsample and average
    var downsampledData = [Float](repeating: 0.0, count: downsampleCount)
    vDSP_desamp(processingBuffer,
                vDSP_Stride(downsampleRate),
                filter,
                &downsampledData,
                vDSP_Length(downsampleCount),
                vDSP_Length(downsampleRate))

    result = downsampledData.map { (value: Float) -> CGFloat in
      let element = CGFloat(value)
      if decibelMax < element {
        decibelMax = element
      }
      return element
    }

    // Remove processed samples
    sampleBuffer.removeFirst(downsampleRate * downsampleCount * MemoryLayout<Int16>.size)

    return result
  }
}
