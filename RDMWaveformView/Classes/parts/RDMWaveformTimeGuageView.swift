//
//  RDMWaveformTimeGuageView.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 4/14/19.
//  Copyright © 2019 reedom. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import SparseRanges

public struct RDMWaveformTimeGuageRendererParams {
  public var labelPaddingLeft: CGFloat = -2
  public var labelPaddingBottom: CGFloat = 1
  public var widthPerSecond: CGFloat = 100
  public var linesPerSecond: Int = 4
  public var majorLinePaddingBottom: CGFloat = 1
  public var minorLinePaddingBottom: CGFloat = 3
  public var majorLineWidth: CGFloat = 1
  public var minorLineWidth: CGFloat = 0.5
  public var font: UIFont = UIFont(name: "Courier", size: 14)!
  public var lineColor: UIColor = UIColor(red: 88/255, green: 88/255, blue: 88/255, alpha: 1)
  public var labelColor: UIColor = UIColor(red: 88/255, green: 88/255, blue: 88/255, alpha: 1)
}

public class RDMWaveformTimeGuageRenderer {
  private let params: RDMWaveformTimeGuageRendererParams

  public init(params: RDMWaveformTimeGuageRendererParams) {
    self.params = params
  }

  public func drawGuage(context: CGContext, timeRange: CountableRange<Int>, rect: CGRect) {
    let fontHeight = params.font.lineHeight + params.labelPaddingBottom
    let majorLineHeight = rect.height - fontHeight - params.majorLinePaddingBottom
    let minorLineHeight = rect.height - fontHeight - params.minorLinePaddingBottom
    let stride = params.widthPerSecond / CGFloat(params.linesPerSecond)
    let textY = rect.height - fontHeight
    let textAttr = [NSAttributedString.Key.foregroundColor: params.labelColor,
                    NSAttributedString.Key.font: params.font ]

    context.setShouldAntialias(false)
    context.setAlpha(1.0)
    context.setStrokeColor(params.lineColor.cgColor)

    var sec = timeRange.lowerBound
    var x = rect.minX - params.labelPaddingLeft
    while (sec < timeRange.upperBound) {
      context.setLineWidth(params.majorLineWidth)
      context.move(to: CGPoint(x: x, y: 0))
      context.addLine(to: CGPoint(x: x, y: majorLineHeight))

      let text = getTimeString(seconds: sec)
      text.draw(at: CGPoint(x: x + params.labelPaddingLeft, y: textY), withAttributes: textAttr)
      sec += 1

      (0..<params.linesPerSecond).forEach { (i) in
        x += stride
        context.setLineWidth(params.minorLineWidth)
        context.move(to: CGPoint(x: x, y: 0))
        context.addLine(to: CGPoint(x: x, y: minorLineHeight))
      }
    }
    context.strokePath()
  }

  private func getTimeString(seconds: Int) -> String {
    let hours = seconds / 3600
    let min = seconds % 3600 / 60
    let sec = seconds % 60
    if hours == 0 {
      return String(format: "%02d:%02d", min, sec)
    } else {
      return String(format: "%d:%02d:%02d", hours, min, sec)
    }
  }
}

public class RDMWaveformTimeGuageView: UIView {
  /// Calcurator around waveform and its view.
  var calculator: RDMWaveformCalc?
  var rendererParams: RDMWaveformTimeGuageRendererParams?

  /// ScrollView's content offset.
  public var contentOffset: CGFloat = 0 {
    didSet { updateGuage() }
  }

  /// A collection of unit views in use.
  private var activeViews = [RDMWaveformTimeGuageUnitView]()
  /// A object pool of deactive unit views.
  private var deactiveViews = [RDMWaveformTimeGuageUnitView]()
}

extension RDMWaveformTimeGuageView {
  private func updateGuage() {
    guard
      let calculator = calculator,
      let rendererParams = rendererParams
      else { return }

    let timeRange = currentTimeRangeInView()

    timeRange.forEach { (seconds) in
      let timeRange = seconds ..< seconds+1
      let baseRect = calculator.rectFrom(timeRange: timeRange, height: frame.height, limits: false)
      if let unitView = activeViews.first(where: { $0.timeRange.lowerBound == seconds }) {
        unitView.frame = baseRect
          .offsetBy(dx: frame.midX - contentOffset, dy: 0)
          .insetBy(dx: rendererParams.labelPaddingLeft, dy: 0)
        return
      }

      let unitView = !deactiveViews.isEmpty ? deactiveViews.removeFirst() : createUnitView()
      activeViews.append(unitView)
      unitView.isHidden = false
      unitView.timeRange = timeRange
      unitView.frame = baseRect
        .offsetBy(dx: frame.midX - contentOffset, dy: 0)
        .insetBy(dx: rendererParams.labelPaddingLeft, dy: 0)
      unitView.setNeedsDisplay()
    }

    activeViews.removeAll(where: { unitView in
      if unitView.timeRange.upperBound <= timeRange.lowerBound ||
        timeRange.upperBound <= unitView.timeRange.lowerBound {
        unitView.isHidden = true
        deactiveViews.append(unitView)
        return true
      }
      return false
    })
  }

  private func createUnitView() -> RDMWaveformTimeGuageUnitView {
    let unitView = RDMWaveformTimeGuageUnitView()
    addSubview(unitView)
    unitView.backgroundColor = UIColor.transparent
    unitView.rendererParams = rendererParams
    return unitView
  }

  private func currentTimeRangeInView() -> TimeRange {
    guard
      0 < frame.width,
      let calculator = calculator
      else { return 0..<0 }
    let from = contentOffset - frame.midX
    let to = contentOffset + frame.width - frame.midX
    let r = calculator.timeRangeInView(from, to, limits: false)
    return Int(r.lowerBound) ..< Int(ceil(r.upperBound))
  }
}

class RDMWaveformTimeGuageUnitView: UIView {
  var timeRange: TimeRange!
  var rendererParams: RDMWaveformTimeGuageRendererParams!

  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else { return }
    let renderer = RDMWaveformTimeGuageRenderer(params: rendererParams)
    renderer.drawGuage(context: context, timeRange: timeRange, rect: rect)
  }
}
