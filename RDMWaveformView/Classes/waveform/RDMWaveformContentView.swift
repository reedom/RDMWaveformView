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

/// A view to display an audio's waveform.
open class RDMWaveformContentView: UIView {

  // MARK: - Properties for downsampling

  /// Downsampler.
  var downsampler: RDMAudioDownsampler?
  /// Calcurator around waveform and its view.
  var calculator: RDMWaveformCalc?
  /// Parameters for the renderer.
  var rendererParams: RDMWaveformRendererParams?

  /// Range of sampling data that `RDMWaveformContentView` instance should render.
  public private(set) var timeRange: TimeRange = 0..<0

  /// Rendering algorithm.
  private var renderer: RDMWaveformRenderer?

  /// Rendering information.
  private struct DrawHint {
    let renderID: Int
    let downsamples: ArraySlice<CGFloat>
    let rect: CGRect
  }

  /// A collection of rendering information.
  private var renderHints = [DrawHint]()

  /// `RDMWaveformContentView` uses this value in the `RDMAudioDownsampler.downsample()` callback
  /// to determine whether the passed data is for the current content or the past. For the latter
  /// case, it should abandon the data.
  private var renderID = 0

  /// Indicates whether `RDMWaveformContentView` is working on rendering.
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

extension RDMWaveformContentView {
  /// Cancel the current rendering procedures.
  public func cancelRendering() {
    renderID = (renderID + 1) % 65536 // prevent overflow, so it's okay with any of enough large number.
  }

  /// Start rendering procedure.
  public func startRenderingProcedure(timeRange: TimeRange) {
    guard
      0 < frame.width,
      let downsampler = downsampler,
      let calculator = calculator,
      let params = rendererParams
      else { return }

    self.timeRange = timeRange
    renderer = RDMWaveformRenderer(params: params, renderFor: timeRange)

    renderHints.removeAll()

    let onComplete = { [weak self] in
      guard let self = self else { return }
      self.rendering = false
    }

    let renderID = self.renderID
    rendering = true
    downsampler.downsample(timeRange: timeRange, onComplete: onComplete) { [weak self] (downsampleRange, downsamples) in
      guard let self = self, renderID == self.renderID else { return }

      let rect = calculator
        .rectFrom(downsampleRange: downsampleRange, height: self.frame.height)
      let hint = DrawHint(renderID: renderID, downsamples: downsamples, rect: rect)
      self.renderHints.append(hint)
      // Put some offset on invalidate rect. Without this, the device will
      // draw a half width line at the edge of the rect.
      self.setNeedsDisplay(hint.rect.offsetBy(dx: -0.5, dy: 0))
    }
  }
}

// MARK: drawing

extension RDMWaveformContentView {
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
      startRenderingProcedure(timeRange: timeRange)
    }

    renderHints.forEach { (renderHint) in
      guard renderHint.renderID == renderID else { return }
      renderer.drawWaveform(context: context, samples: renderHint.downsamples, rect: renderHint.rect)
    }

    renderHints.removeAll()
  }
}
