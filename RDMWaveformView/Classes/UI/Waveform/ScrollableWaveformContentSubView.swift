//
//  ScrollableWaveformContentSubView.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/21.
//

import UIKit
import MediaPlayer
import AVFoundation
import SparseRanges

/// A view to display an audio's waveform.
open class ScrollableWaveformContentSubView: UIView {

  // MARK: - Properties for downsampling

  /// Downsampler.
  var downsampler: Downsampler?
  /// Downsampler(adhoc usage).
  var adhocDownsampler: AdhocDownsampler?
  /// Calcurator around waveform and its view.
  var calculator: WaveformCalc?
  /// Parameters for the renderer.
  var rendererParams: WaveformRendererParams? {
    didSet {
      if let params = rendererParams {
        renderer = WaveformRenderer(params: params)
      } else {
        renderer = nil
      }
    }
  }

  /// Range of sampling data that `WaveformContentView` instance should render.
  public private(set) var timeRange: TimeRange = 0..<0
  /// X-axis offset of the waveform content where this view originally represents.
  public private(set) var contentOffset: CGFloat = 0

  /// Rendering algorithm.
  private var renderer: WaveformRenderer?

  /// Rendering information.
  private struct DrawHint {
    let renderID: Int
    let downsamples: ArraySlice<CGFloat>
    let rect: CGRect
  }

  /// A collection of rendering information.
  private var renderHints = [DrawHint]()

  /// `WaveformContentView` uses this value in the `Downsampler.downsample()` callback
  /// to determine whether the passed data is for the current content or the past. For the latter
  /// case, it should abandon the data.
  private var renderID = 0

  /// Indicates whether `WaveformContentView` is working on rendering.
  private var rendering = false

  // MARK: - Init

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    backgroundColor = UIColor.transparent
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = UIColor.transparent
  }
}

extension ScrollableWaveformContentSubView {
  /// Cancel the current rendering procedures.
  public func cancelRendering() {
    renderID = (renderID + 1) % 65536 // prevent overflow, so it's okay with any of enough large number.
  }

  /// Start rendering procedure.
  func startRendering(timeRange: TimeRange, contentOffset: CGFloat = 0) {
    self.timeRange = timeRange
    self.contentOffset = contentOffset
    startRendering()
  }

  private func startRendering() {
    guard
      0 < frame.width,
      let downsampler = downsampler,
      let adhocDownsampler = adhocDownsampler,
      let calculator = calculator
      else { return }

    renderHints.removeAll()

    let onComplete = { [weak self] in
      guard let self = self else { return }
      self.rendering = false
    }

    if let downsamples = downsampler.downsample(downsampleRate: calculator.downsampleRate, timeRange: timeRange) {
      let downsampleRange = downsampleRangeFrom(calculator.audioContext, calculator.downsampleRate, timeRange: timeRange)
      prepareDrawing(downsampleRange, downsamples)
      return
    }

    cancelRendering()
    let renderID = self.renderID
    rendering = true
    adhocDownsampler.downsample(timeRange: timeRange, onComplete: onComplete) { [weak self] (downsampleRange, downsamples) in
      guard let self = self, renderID == self.renderID else { return }
      self.prepareDrawing(downsampleRange, downsamples)
    }
  }

  private func prepareDrawing(_ downsampleRange: DownsampleRange, _ downsamples: ArraySlice<CGFloat>) {
    guard let calculator = calculator else { return }
    let rect = calculator
      .rectFrom(downsampleRange: downsampleRange, height: self.frame.height)
      .offsetBy(dx: -contentOffset, dy: 0)
    let hint = DrawHint(renderID: renderID, downsamples: downsamples, rect: rect)
    self.renderHints.append(hint)
    // Put some offset on invalidate rect. Without this, the device will
    // draw a half width line at the edge of the rect.
    self.setNeedsDisplay(hint.rect.offsetBy(dx: -0.5, dy: 0))
  }
}

// MARK: drawing

extension ScrollableWaveformContentSubView {
  override open func draw(_ rect: CGRect) {
    guard
      0 < frame.width,
      let context = UIGraphicsGetCurrentContext(),
      let renderer = renderer
      else { return }

    if renderHints.isEmpty && !rendering {
      // This happens when
      // a) initial rendering
      // b) iOS had flushed the rendering buffer while the app was in background
      startRendering()
    }

    renderHints.forEach { (renderHint) in
      guard renderHint.renderID == renderID else { return }
      renderer.drawWaveform(context: context, samples: renderHint.downsamples, rect: renderHint.rect)
    }

    renderHints.removeAll()
  }
}
