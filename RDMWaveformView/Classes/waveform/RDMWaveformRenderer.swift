//
//  RDMWaveformRenderer.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/06.
//

import UIKit

public struct RDMWaveformRendererParams {
  public var decibelMin: CGFloat
  public var decibelMax: CGFloat

  public var resolution: RDMWaveformResolution
  public var totalWidth: CGFloat
  public var marginLeft: CGFloat
  public var lineColor: UIColor
}

public class RDMWaveformRenderer {
  public typealias DownsampleRange = CountableRange<Int>

  private let decibelMin: CGFloat
  private let decibelMax: CGFloat

  private let resolution: RDMWaveformResolution
  private let totalWidth: CGFloat
  private let marginLeft: CGFloat
  private let lineColor: UIColor

  private let lineWidth: CGFloat
  private let lineStride: CGFloat

  public init(params: RDMWaveformRendererParams,
              renderFor downsampleRange: DownsampleRange) {
    self.decibelMin = params.decibelMin
    self.decibelMax = params.decibelMax
    self.resolution = params.resolution
    self.totalWidth = params.totalWidth
    self.marginLeft = params.marginLeft
    self.lineColor = params.lineColor

    self.lineStride = resolution.lineStride
    self.lineWidth = resolution.lineWidth
  }

  public func drawWaveform(context: CGContext, samples: ArraySlice<CGFloat>, rect: CGRect) {
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
    var x = rect.minX + marginLeft
    for (_, sample) in samples.enumerated() {
      let height = max((sample - decibelMin) * sampleDrawingScale, 0.5)
      context.move(to: CGPoint(x: x, y: verticalMiddle - height))
      context.addLine(to: CGPoint(x: x, y: verticalMiddle + height))
      x += lineStride
    }
    context.strokePath();
  }
}
