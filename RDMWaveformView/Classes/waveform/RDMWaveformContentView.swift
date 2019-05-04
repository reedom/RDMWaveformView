//
//  RDMWaveformContentView.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 4/18/19.
//

import UIKit
import MediaPlayer
import AVFoundation
import SparseRanges

public enum RDMWaveformResolution {
  case byViewWidth(stride: CGFloat, lineWidth: CGFloat)
  case perSecond(width: Int, lines: Int, lineWidth: CGFloat)
}

/// A view for rendering audio waveforms
open class RDMWaveformContentView: UIView {
  // MARK: - Fundamental properties

  /// Current audio context to be used for rendering
  public var audioContext: RDMAudioContext? {
    didSet {
      setup()
    }
  }

  public var resolution: RDMWaveformResolution? {
    didSet {
      setup();
    }
  }

  var downsampler: RDMAudioDownsampler?

  open var preloadIfTrackShorterThan: TimeInterval = 5*60 {
    didSet {
      guard 0 < totalSamples else { return }
      if duration.seconds < preloadIfTrackShorterThan {
        downsampler?.downsampleAll()
      }
    }
  }

  // MARK: - Audio helper properties

  /// The total number of audio samples in the current track.
  public var totalSamples: Int {
    return audioContext?.totalSamples ?? 0
  }

  /// The total duration of the current track.
  public var duration: CMTime {
    return audioContext?.asset.duration ?? CMTime.zero
  }

  // MARK: - Drawing properties

  public var renderingUnitFactor: Float = 1.5
  public var marginLeft: CGFloat = 0
  /// Visible width on the screen. The width of the parent view should relate this.
  public var visibleWidth: CGFloat = 0

  public var contentWidth: CGFloat {
    guard let resolution = resolution else { return 0 }
    switch resolution {
    case .byViewWidth(_, _):
      return visibleWidth
    case .perSecond(let widthPerSecond, _, _):
      return CGFloat(widthPerSecond) * CGFloat(duration.seconds)
    }
  }

  /// The color of the waveform
  public var lineColor: UIColor = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)

  public var decibelMin: CGFloat = -50
  public var decibelMax: CGFloat = -10

  public typealias ScrollDirection = RDMScrollableWaveformView.ScrollDirection
  public typealias TimeRange = CountableRange<Int>

  private var renderedTimeRanges = SparseCountableRange<Int>()

  private struct DrawHint {
    let downsamples: ArraySlice<CGFloat>
    let rect: CGRect
  }

  private var renderHints = [DrawHint]()

  private var contentOffset: CGFloat = 0

  private var hasInitialRenderingDone = false
}

extension RDMWaveformContentView {
  public func update(contentOffset: CGFloat = 0, direction: ScrollDirection = .none) {
    self.contentOffset = contentOffset
    guard let resolution = resolution, 0 < visibleWidth else { return }

    var (lowerBound, upperBound) = currentTimeRangeInView()
    let d = upperBound - lowerBound

    var timeRange: TimeRange
    switch resolution {
    case .byViewWidth(_, _):
      timeRange = 0 ..< Int(ceil(duration.seconds))
      break
    case .perSecond(_, _, _):
      switch direction {
      case .backward:
        lowerBound = upperBound -  d * Double(renderingUnitFactor)
      case .forward:
        upperBound = lowerBound + d * Double(renderingUnitFactor)
      case .none:
        let m = upperBound - d / 2
        lowerBound = m - d * Double(renderingUnitFactor) / 2
        upperBound = m + d * Double(renderingUnitFactor) / 2
      }
      timeRange = max(0, Int(lowerBound)) ..< Int(max(0, min(ceil(duration.seconds), ceil(upperBound))))
    }

    guard
      let gaps = renderedTimeRanges.gaps(timeRange),
      let downsampler = downsampler else { return }

    let onComplete = { [weak self] in
      guard let self = self else { return }
      if !self.hasInitialRenderingDone {
        self.hasInitialRenderingDone = true
        if self.duration.seconds < self.preloadIfTrackShorterThan {
          self.downsampler?.downsampleAll()
        }
      }
    }

    gaps.forEach { (timeRange) in
      renderedTimeRanges.add(timeRange)
      let sampleRange = sampleRangeFrom(timeRange: timeRange)
      downsampler.downsample(samplesRange: sampleRange, onComplete: onComplete) { [weak self] (chunkRange, downsamples) in
        guard let self = self else { return }
        let hint = DrawHint(downsamples: downsamples,
                            rect: self.rectFrom(sampleRange: chunkRange))
        self.renderHints.append(hint)
        // Put some offset on invalidate rect. Without this, the device will
        // draw a half width line at the edge of the rect.
        self.setNeedsDisplay(hint.rect.offsetBy(dx: -0.5, dy: 0))
      }
    }
  }

  private func calcDownsampleRate() -> Int {
    guard let resolution = resolution else { return 1 }

    switch resolution {
    case .byViewWidth(let stride, _):
      let lines = frame.width / CGFloat(stride)
      guard 0 < lines else { return 1 }
      return max(1, Int(CGFloat(totalSamples) / lines))
    case .perSecond(_, let linesPerSecond, _):
      let totalLines = duration.seconds * Double(linesPerSecond)
      return max(1, Int(ceil(Double(totalSamples) / totalLines)))
    }
  }

  open func cancel() {
    downsampler?.cancel()
  }

  open func reset() {
    hasInitialRenderingDone = false
    renderedTimeRanges.removeAll()
    renderHints.removeAll()
    downsampler?.reset()
  }

  open func setup() {
    guard let audioContext = audioContext, resolution != nil else {
      downsampler = nil
      return
    }

    downsampler = RDMAudioDownsampler(
      audioContext: audioContext,
      downsampleRate: calcDownsampleRate(),
      decibelMax: decibelMax,
      decibelMin: decibelMin)
  }
}

// MARK: - unit converters

extension RDMWaveformContentView {
  private func sampleIndexFrom(x: CGFloat) -> Int {
    guard let resolution = resolution else { return 0 }
    switch resolution {
    case .byViewWidth(_, _):
      let progress = x / frame.width
      return max(0, min(totalSamples, Int(CGFloat(totalSamples) * progress)))
    case .perSecond(let widthPerSecond, _, _):
      let seconds = x / CGFloat(widthPerSecond)
      let progress = seconds / CGFloat(duration.seconds)
      return max(0, min(totalSamples, Int(CGFloat(totalSamples) * progress)))
    }
  }

  private func sampleRangeFrom(viewRange: ViewRange) -> ViewRange {
    let x1 = sampleIndexFrom(x: CGFloat(viewRange.lowerBound))
    let x2 = sampleIndexFrom(x: CGFloat(viewRange.upperBound))
    return x1..<x2
  }

  private func sampleIndexFrom(seconds: Double) -> Int {
    let totalSeconds = duration.seconds
    guard 0 < totalSeconds else { return 0 }

    let progress = seconds / totalSeconds
    return max(0, min(totalSamples, Int(Double(totalSamples) * progress)))
  }

  private typealias SampleRange = CountableRange<Int>

  private func sampleRangeFrom(timeRange: TimeRange) -> SampleRange {
    let beg = sampleIndexFrom(seconds: Double(timeRange.lowerBound))
    let end = sampleIndexFrom(seconds: Double(timeRange.upperBound))
    return beg ..< end
  }

  private func currentTimeRangeInView() -> (lowerBound: Double, upperBound: Double) {
    guard let resolution = resolution else { return (0, 0) }

    let totalSeconds = duration.seconds
    switch resolution {
    case .byViewWidth(_, _):
      let lowerBound = Double((contentOffset - marginLeft) / frame.width) * totalSeconds
      let upperBound = Double((contentOffset + visibleWidth - marginLeft) / frame.width) * totalSeconds
      return (max(0, min(totalSeconds, lowerBound)), max(0, min(totalSeconds, upperBound)))
    case .perSecond(let widthPerSecond, _, _):
      let lowerBound = Double((contentOffset - marginLeft) / CGFloat(widthPerSecond))
      let upperBound = Double((contentOffset + visibleWidth - marginLeft) / CGFloat(widthPerSecond))
      return (lowerBound, upperBound)
    }
  }

  private func visibleRect() -> CGRect {
    return CGRect(x: contentOffset, y: 0, width: visibleWidth, height: frame.height)
  }

  private func xFrom(seconds: Double) -> CGFloat {
    let totalSeconds = duration.seconds
    guard 0 < totalSeconds else { return 0 }

    let progress = seconds / totalSeconds
    return max(0, min(frame.width, frame.width * CGFloat(progress)))
  }

  private func xFrom(sampleIndex: Int) -> CGFloat {
    guard
      0 < totalSamples,
      let resolution = resolution else { return 0 }

    switch resolution {
    case .byViewWidth(let stride, _):
      let progress = CGFloat(sampleIndex) / CGFloat(totalSamples)
      let index = visibleWidth * progress
      let maxIndex = visibleWidth / CGFloat(stride)
      return stride * max(0, floor(min(maxIndex, index)))
    case .perSecond(let widthPerSecond, let linesPerSecond, _):
      let downsampleRate = calcDownsampleRate()
      let stride = widthPerSecond / linesPerSecond
      let index = round(CGFloat(sampleIndex / downsampleRate))
      return max(0, min(frame.width, index * CGFloat(stride)))
    }
  }

  private func rectFrom(timeRange: TimeRange) -> CGRect {
    let x1 = xFrom(seconds: Double(timeRange.lowerBound))
    let x2 = xFrom(seconds: Double(timeRange.upperBound))
    return CGRect(x: x1, y: 0, width: x2 - x1, height: frame.height)
  }

  private func rectFrom(sampleRange: SampleRange) -> CGRect {
    let x1 = xFrom(sampleIndex: sampleRange.lowerBound)
    let x2 = xFrom(sampleIndex: sampleRange.upperBound)
    return CGRect(x: x1, y: 0, width: x2 - x1, height: frame.height)
  }
}

// MARK: drawing

extension RDMWaveformContentView {
  private typealias ViewRange = CountableRange<Int>

  public var lineWidth: CGFloat {
    guard let resolution = resolution else { return 1 }
    switch resolution {
    case .byViewWidth(_, let lineWidth):
      return lineWidth
    case .perSecond(_, _, let lineWidth):
      return lineWidth
    }
  }

  public var lineStride: CGFloat {
    guard let resolution = resolution else { return 0 }
    switch resolution {
    case .byViewWidth(let stride, _):
      return stride
    case .perSecond(let width, let lines, _):
      return CGFloat(width) / CGFloat(lines)
    }
  }
}

extension RDMWaveformContentView {
  override open func draw(_ rect: CGRect) {
    guard
      audioContext != nil,
      0 < visibleWidth,
      let context = UIGraphicsGetCurrentContext()
      else { return }

    if renderHints.isEmpty {
      // This happens when
      // a) initial rendering
      // b) iOS had flushed the rendering buffer while the app was in background
      renderedTimeRanges.removeAll()
      update(contentOffset: contentOffset, direction: .none)
    }

    renderHints.forEach { (renderHint) in
      drawWaveform(context: context, samples: renderHint.downsamples, rect: renderHint.rect)
    }

    renderHints.removeAll()
  }

  // MARK: - draw waveform

  private func drawWaveform(context: CGContext, samples: ArraySlice<CGFloat>, rect: CGRect) {
    context.setShouldAntialias(false)
    context.setAlpha(1.0)
    context.setLineWidth(CGFloat(lineWidth))
    context.setStrokeColor(lineColor.cgColor)

    let sampleDrawingScale: CGFloat
    if decibelMax == decibelMin {
      sampleDrawingScale = 0
    } else {
      sampleDrawingScale = rect.height / 2 / (decibelMax - decibelMin)
    }
    let verticalMiddle = rect.height / 2
    var x = rect.minX
    let lineStride = self.lineStride
    for (_, sample) in samples.enumerated() {
      let height = max((sample - decibelMin) * sampleDrawingScale, 0.5)
      context.move(to: CGPoint(x: x, y: verticalMiddle - height))
      context.addLine(to: CGPoint(x: x, y: verticalMiddle + height))
      x += lineStride
    }
    context.strokePath();
  }
}