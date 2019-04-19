//
//  RDMWaveformContentView.swift
//  FBSnapshotTestCase
//
//  Created by HANAI Tohru on 4/18/19.
//

import UIKit
import MediaPlayer
import AVFoundation
import SparseRanges

/// A view for rendering audio waveforms
// IBDesignable support in XCode is so broken it's sad
open class RDMWaveformContentView: UIView {
  /// A delegate to accept progress reporting
  open weak var delegate: RDMWaveformViewDelegate?

  /// The color of the waveform
  public var lineColor: UIColor = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)

  private var renderSources = [RDMWaveformRenderSource]()

  public func add(renderSource: RDMWaveformRenderSource) {
    renderSources.append(renderSource)
    self.setNeedsDisplay(renderSource.calculator.targetRect.insetBy(dx: -2, dy: 0))
  }

  open func reset() {
    // TODO
  }

  // MARK: drawing

  override open func draw(_ rect: CGRect) {
    print("draw: rect = \(rect), frame = \(frame)")

    guard let context = UIGraphicsGetCurrentContext() else {
      print("RDMWaveformView failed to get graphics context")
      return
    }

    delegate?.waveformViewWillRender?(nil)
    renderSources.forEach { (renderSource) in
      drawWaveform(context: context, renderSource: renderSource,
                   rect: renderSource.calculator.targetRect)
    }
    renderSources.removeAll()
    delegate?.waveformViewDidRender?(nil)
  }

  // MARK: - draw waveform

  private func drawWaveform(context: CGContext, renderSource: RDMWaveformRenderSource, rect: CGRect) {
    let calculator = renderSource.calculator
    print("targetRect = \(rect)")
    context.setShouldAntialias(false)
    context.setAlpha(1.0)
    context.setLineWidth(CGFloat(calculator.lineWidth))
    context.setStrokeColor(lineColor.cgColor)

    let sampleDrawingScale: CGFloat
    if renderSource.decibelMax == renderSource.decibelMin {
      sampleDrawingScale = 0
    } else {
      sampleDrawingScale = rect.height / 2 / (renderSource.decibelMax - renderSource.decibelMin)
    }
    let verticalMiddle = rect.height / 2
    for (i, sample) in renderSource.samples.enumerated() {
      let x = rect.minX + CGFloat(i * (calculator.lineWidth + calculator.lineStride))
      let height = max((sample - renderSource.decibelMin) * sampleDrawingScale, 0.5)
      context.move(to: CGPoint(x: x, y: verticalMiddle - height))
      context.addLine(to: CGPoint(x: x, y: verticalMiddle + height))
    }
    context.strokePath();
  }
}
