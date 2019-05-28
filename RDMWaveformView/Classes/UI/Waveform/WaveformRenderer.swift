//
//  WaveformRenderer.swift
//  WaveformView
//
//  Created by HANAI Tohru on 2019/05/06.
//

import UIKit

public struct WaveformRendererParams {
  public var decibelMin: CGFloat
  public var decibelMax: CGFloat

  public var resolution: WaveformResolution
  public var totalWidth: CGFloat
  public var marginLeft: CGFloat
  public var lineColor: UIColor
}

public class WaveformRenderer {
  private let params: WaveformRendererParams

  public init(params: WaveformRendererParams) {
    self.params = params
  }

  public func drawWaveform(context: CGContext, samples: ArraySlice<CGFloat>, rect: CGRect) {
    let lineStride = params.resolution.lineStride
    let lineWidth = params.resolution.lineWidth

    context.setShouldAntialias(false)
    context.setAlpha(1.0)
    context.setLineWidth(CGFloat(lineWidth))
    context.setStrokeColor(params.lineColor.cgColor)

    let sampleDrawingScale: CGFloat
    if params.decibelMax == params.decibelMin {
      sampleDrawingScale = 0
    } else {
      sampleDrawingScale = rect.height / 2 / (params.decibelMax - params.decibelMin)
    }
    let verticalMiddle = rect.height / 2
    var x = rect.minX + params.marginLeft
    for (_, sample) in samples.enumerated() {
      let height = max((sample - params.decibelMin) * sampleDrawingScale, 0.5)
      context.move(to: CGPoint(x: x, y: verticalMiddle - height))
      context.addLine(to: CGPoint(x: x, y: verticalMiddle + height))
      x += lineStride
    }
    context.strokePath();
  }
}
