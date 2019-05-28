//
//  WaveformContentView.swift
//  WaveformView
//
//  Created by HANAI Tohru on 4/18/19.
//

import UIKit
import MediaPlayer
import AVFoundation
import SparseRanges

/// A view to display an audio's waveform.
open class WaveformContentView: UIView {

  // MARK: - Properties for downsampling

  /// Downsampler.
  public private(set) var downsampler: Downsampler?

  /// Calcurator around waveform and its view.
  public private(set) var calculator: WaveformCalc?

  /// Parameters for the renderer.
  var rendererParams: WaveformRendererParams? {
    didSet {
      if let rendererParams = rendererParams {
        renderer = WaveformRenderer(params: rendererParams)
        renderHints.removeAll()
      } else {
        renderer = nil
      }
    }
  }

  /// Rendering algorithm.
  private var renderer: WaveformRenderer?

  /// Rendering information.
  private struct DrawHint {
    let downsamples: ArraySlice<CGFloat>
    let rect: CGRect
  }

  /// A collection of rendering information.
  private var renderHints = [DrawHint]()

  // MARK: - Init

  public required init?(coder aDecoder: NSCoder) {
    fatalError()
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = UIColor.transparent
  }

  deinit {
    if let downsampler = downsampler, let calculator = calculator {
      downsampler.removeHandler(downsampleRate: calculator.downsampleRate, handler: self)
    }
  }
}

extension WaveformContentView: DownsampledHandler {
  public func setup(_ calculator: WaveformCalc, _ downsampler: Downsampler) {
    if let oldCalculator = self.calculator, let oldDownsampler = self.downsampler {
      if oldCalculator == calculator && oldDownsampler == downsampler {
        return
      }
      downsampler.removeHandler(downsampleRate: calculator.downsampleRate, handler: self)
    }

    self.downsampler = downsampler
    self.calculator = calculator
    downsampler.addHandler(downsampleRate: calculator.downsampleRate, handler: self)
  }

  func downsamplerDidDownsample(downsampleRange: DownsampleRange, downsamples: ArraySlice<CGFloat>) {
    guard let calculator = calculator else { return }
    let rect = calculator.rectFrom(downsampleRange: downsampleRange, height: self.frame.height)
    let hint = DrawHint(downsamples: downsamples, rect: rect)

    DispatchQueue.main.async {
      self.renderHints.append(hint)
      // Put some offset on invalidate rect. Without this, the device will
      // draw a half width line at the edge of the rect.
      self.setNeedsDisplay(hint.rect.offsetBy(dx: -0.5, dy: 0))
    }
  }
}

// MARK: drawing

extension WaveformContentView {
  override open func draw(_ rect: CGRect) {
    guard
      0 < frame.width,
      let context = UIGraphicsGetCurrentContext(),
      let renderer = renderer,
      let downsampler = downsampler
      else { return }

    if renderHints.isEmpty && downsampler.status != .loading {
      // This happens when
      // a) initial rendering
      // b) iOS had flushed the rendering buffer while the app was in background
      redraw()
    }

    renderHints.forEach { (renderHint) in
      renderer.drawWaveform(context: context, samples: renderHint.downsamples, rect: renderHint.rect)
    }

    renderHints.removeAll()
  }

  private func redraw() {

  }
}
