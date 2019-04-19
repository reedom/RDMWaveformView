//
// Copyright 2013 - 2017, William Entriken and the RDMWaveformView contributors.
//
import UIKit
import AVFoundation
import Accelerate

public struct RDMWaveformRenderSource {
  let samples: [CGFloat]
  let decibelMax: CGFloat
  let decibelMin: CGFloat
  let calculator: RDMWaveformCalculator
}

public enum RDMOperationState {
  case idle
  case executing
  case finished
  case cancelled
}

/// Operation used for rendering waveform images
final public class RDMWaveformLoadOperation: Operation {
  public let calculator: RDMWaveformCalculator
  public let decibelMin: CGFloat
  public var decibelMax: CGFloat

  // MARK: - NSOperation Overrides

  public override var isAsynchronous: Bool { return true }

  private var _state = RDMOperationState.idle
  public var state: RDMOperationState {
    get { return _state }
  }

  public override var isExecuting: Bool { return _state == .executing }
  public override var isFinished: Bool { return _state == .finished }

  // MARK: - Private

  ///  Handler called when the rendering has completed. nil UIImage indicates that there was an error during processing.
  private let completionHandler: (RDMWaveformRenderSource?) -> ()

  /// Final rendered image. Used to hold image for completionHandler.
  private var renderSource: RDMWaveformRenderSource?

  init(calculator: RDMWaveformCalculator,
       decibelMin: CGFloat,
       decibelMax: CGFloat,
       completionHandler: @escaping (_ renderSource: RDMWaveformRenderSource?) -> ()) {
    self.calculator = calculator
    self.decibelMin = decibelMin
    self.decibelMax = decibelMax
    self.completionHandler = completionHandler

    super.init()

    self.completionBlock = { [weak self] in
      guard let `self` = self else { return }
      self.completionHandler(self.renderSource)
      self.renderSource = nil
    }
  }

  public override func start() {
    guard _state == .idle else { return }

    willChangeValue(forKey: "isExecuting")
    _state = .executing
    didChangeValue(forKey: "isExecuting")

    if #available(iOS 8.0, *) {
      DispatchQueue.global(qos: .background).async { self.render() }
    } else {
      DispatchQueue.global(priority: .background).async { self.render() }
    }
  }

  private func finish(with renderSource: RDMWaveformRenderSource?) {
    guard _state == .executing else { return }

    self.renderSource = renderSource

    // completionBlock called automatically by NSOperation after these values change
    willChangeValue(forKey: "isExecuting")
    willChangeValue(forKey: "isFinished")
    _state = .finished
    didChangeValue(forKey: "isExecuting")
    didChangeValue(forKey: "isFinished")
  }

  private func render() {
    var renderSource: RDMWaveformRenderSource?
    if calculator.isValid, let samples = sliceAsset() {
      renderSource = RDMWaveformRenderSource(samples: samples,
                                             decibelMax: decibelMax,
                                             decibelMin: decibelMin,
                                             calculator: calculator)
    }
    finish(with: renderSource)
  }

  /// Read the asset and create create a lower resolution set of samples
  func sliceAsset() -> [CGFloat]? {
    let slice = calculator.sampleRange
    let audioContext = calculator.audioContext

    guard
      !isCancelled,
      !slice.isEmpty,
      0 < calculator.targetSamples,
      let reader = try? AVAssetReader(asset: audioContext.asset)
    else { return nil }

    let duration = audioContext.asset.duration
    reader.timeRange = CMTimeRange(start: CMTime(value: Int64(slice.lowerBound), timescale: duration.timescale),
                                   duration: CMTime(value: Int64(slice.count), timescale: duration.timescale))
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

    let samplesPerPixel = max(1, audioContext.channelCount * slice.count / calculator.targetSamples)
    let filter = [Float](repeating: 1.0 / Float(samplesPerPixel), count: samplesPerPixel)

    var outputSamples = [CGFloat]()
    var sampleBuffer = Data()

    // 16-bit samples
    reader.startReading()
    defer { reader.cancelReading() } // Cancel reading if we exit early if operation is cancelled

    while reader.status == .reading {
      guard !isCancelled else { return nil }

      guard
        let readSampleBuffer = readerOutput.copyNextSampleBuffer(),
        let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer)
        else { break }

      // Append audio sample buffer into our current sample buffer
      var readBufferLength = 0
      var readBufferPointer: UnsafeMutablePointer<Int8>?
      CMBlockBufferGetDataPointer(readBuffer, atOffset: 0, lengthAtOffsetOut: &readBufferLength, totalLengthOut: nil, dataPointerOut: &readBufferPointer)
      sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
      CMSampleBufferInvalidate(readSampleBuffer)

      let totalSamples = sampleBuffer.count / MemoryLayout<Int16>.size
      let downSampledLength = totalSamples / samplesPerPixel
      let samplesToProcess = downSampledLength * samplesPerPixel

      guard 0 < samplesToProcess else { continue }

      processSamples(fromData: &sampleBuffer,
                     outputSamples: &outputSamples,
                     samplesToProcess: samplesToProcess,
                     downSampledLength: downSampledLength,
                     samplesPerPixel: samplesPerPixel,
                     filter: filter)
    }

    guard !isCancelled else { return nil }

    if 0 < sampleBuffer.count {
      print("there are remaining samples but just ignore it since they are too small to process")
    }

    // if (reader.status == AVAssetReaderStatusFailed || reader.status == AVAssetReaderStatusUnknown)
    // Something went wrong. Handle it, or not depending on if you can get above to work
    if reader.status != .completed {
      print("RDMWaveformRenderOperation ends not in completed state: \(String(describing: reader.error))")
    }
    return outputSamples
  }

  private func clipSample(normalizedSamples: inout [Float]) {
    // Convert samples to a log scale
    var zero: Float = 32768.0
    vDSP_vdbcon(normalizedSamples, 1, &zero, &normalizedSamples, 1, vDSP_Length(normalizedSamples.count), 1)

    //Clip to [noiseFloor, 0]
    var ceil: Float = 0.0
    var noiseFloorFloat = Float(decibelMin)
    vDSP_vclip(normalizedSamples, 1, &noiseFloorFloat, &ceil, &normalizedSamples, 1, vDSP_Length(normalizedSamples.count))
  }

  // TODO: report progress? (for issue #2)
  func processSamples(fromData sampleBuffer: inout Data,
                      outputSamples: inout [CGFloat],
                      samplesToProcess: Int,
                      downSampledLength: Int,
                      samplesPerPixel: Int,
                      filter: [Float]) {
//    sampleBuffer.withUnsafeBytes { (pointer) in
//      let samples = pointer.load(as: UnsafePointer<Int16>.self)
    sampleBuffer.withUnsafeBytes { (samples: UnsafePointer<Int16>) in
      var processingBuffer = [Float](repeating: 0.0, count: samplesToProcess)

      let sampleCount = vDSP_Length(samplesToProcess)

      // Convert 16bit int samples to floats
      vDSP_vflt16(samples, 1, &processingBuffer, 1, sampleCount)

      // Take the absolute values to get amplitude
      vDSP_vabs(processingBuffer, 1, &processingBuffer, 1, sampleCount)

      clipSample(normalizedSamples: &processingBuffer)

      //Downsample and average
      var downSampledData = [Float](repeating: 0.0, count: downSampledLength)
      vDSP_desamp(processingBuffer,
                  vDSP_Stride(samplesPerPixel),
                  filter,
                  &downSampledData,
                  vDSP_Length(downSampledLength),
                  vDSP_Length(samplesPerPixel))

      let downSampledDataCG = downSampledData.map { (value: Float) -> CGFloat in
        let element = CGFloat(value)
        if decibelMax < element {
          decibelMax = element
        }
        return element
      }

      // Remove processed samples
      sampleBuffer.removeFirst(samplesToProcess * MemoryLayout<Int16>.size)

      outputSamples += downSampledDataCG
    }
  }

  private func process(_ normalizedSamples: inout [Float], noiseFloor: Float) {
    // Convert samples to a log scale
    var zero: Float = 32768.0
    vDSP_vdbcon(normalizedSamples, 1, &zero, &normalizedSamples, 1, vDSP_Length(normalizedSamples.count), 1)

    //Clip to [noiseFloor, 0]
    var ceil: Float = 0.0
    var noiseFloorFloat = noiseFloor
    vDSP_vclip(normalizedSamples, 1, &noiseFloorFloat, &ceil, &normalizedSamples, 1, vDSP_Length(normalizedSamples.count))
  }
}

//extension AVAssetReader.Status : CustomStringConvertible {
//  public var description: String{
//    switch self {
//    case .reading: return "reading"
//    case .unknown: return "unknown"
//    case .completed: return "completed"
//    case .failed: return "failed"
//    case .cancelled: return "cancelled"
//    }
//  }
//}
