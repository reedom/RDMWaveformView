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

public class RDMWaveformTimeGuageView: UIView {
  public var visibleWidth: CGFloat = 0 {
    didSet { setNeedsDisplay() }
  }
  public var marginLeft: CGFloat = 0 {
    didSet { setNeedsDisplay() }
  }
  public var labelPaddingLeft: CGFloat = -2 {
    didSet { setNeedsDisplay() }
  }
  public var labelPaddingBottom: CGFloat = 1 {
    didSet { setNeedsDisplay() }
  }
  public var widthPerSecond: CGFloat = 100 {
    didSet { setNeedsDisplay() }
  }
  public var linesPerSecond: Int = 4 {
    didSet { setNeedsDisplay() }
  }
  public var majorLinePaddingBottom: CGFloat = 1 {
    didSet { setNeedsDisplay() }
  }
  public var minorLinePaddingBottom: CGFloat = 3 {
    didSet { setNeedsDisplay() }
  }
  public var majorLineWidth: CGFloat = 1 {
    didSet { setNeedsDisplay() }
  }
  public var minorLineWidth: CGFloat = 0.5 {
    didSet { setNeedsDisplay() }
  }
  public var font: UIFont = UIFont(name: "Courier", size: 14)! {
    didSet { setNeedsDisplay() }
  }
  public var lineColor: UIColor = UIColor(red: 88/255, green: 88/255, blue: 88/255, alpha: 1) {
    didSet { setNeedsDisplay() }
  }
  public var labelColor: UIColor = UIColor(red: 88/255, green: 88/255, blue: 88/255, alpha: 1) {
    didSet { setNeedsDisplay() }
  }

  public var contentOffset: CGFloat = 0 {
    didSet {
      if let rect = calcRectNeedToDraw() {
        setNeedsDisplay(rect)
      }
    }
  }

  private var renderedTimeRanges = SparseCountableRange<Int>()
  private var timeRanges = [CountableRange<Int>]()

  public func refresh() {
    renderedTimeRanges.removeAll()
    timeRanges.removeAll()
  }

  private func calcRectNeedToDraw() -> CGRect? {
    guard
      0 < visibleWidth,
      0 < widthPerSecond,
      0 < linesPerSecond else { return nil }

    // `RDMWaveformTimeGuageView` should draw the current visible range plus ±1sec.

    // First, we calculate time range of visible part of the view.
    let beg = (contentOffset - marginLeft) / widthPerSecond
    let end = (contentOffset - marginLeft + visibleWidth) / widthPerSecond

    // Second, create range of beg-1 ..< end+1
    let range = max(0, Int(beg) - 1) ..< max(0, Int(ceil(end)) + 1)

    if let gaps = renderedTimeRanges.gaps(range) {
      let gap = gaps.first!
      renderedTimeRanges.add(gap)
      timeRanges.append(gap)
      return rectFrom(timeRange: gap)
    } else {
      return nil
    }
  }

  private func rectFrom(timeRange: CountableRange<Int>) -> CGRect {
    let x = CGFloat(timeRange.lowerBound) * widthPerSecond + marginLeft
    let width = CGFloat(timeRange.count) * widthPerSecond
    return CGRect(x: x, y: 0, width: width, height: frame.height)
  }

  override public func draw(_ rect: CGRect) {
    guard
      0 < visibleWidth,
      0 < widthPerSecond,
      0 < linesPerSecond,
     let context = UIGraphicsGetCurrentContext() else {
      return
    }

    if timeRanges.isEmpty {
      // This happens when
      // a) initial rendering
      // b) iOS had flushed the rendering buffer while the app was in background
      renderedTimeRanges.removeAll()
      _ = calcRectNeedToDraw()
    }

    timeRanges.forEach { (timeRange) in
      drawGuage(context: context, timeRange: timeRange)
    }
    timeRanges.removeAll()
  }

  private func drawGuage(context: CGContext, timeRange: CountableRange<Int>) {
    let rect = rectFrom(timeRange: timeRange)
    let fontHeight = font.lineHeight + labelPaddingBottom
    let majorLineHeight = frame.height - fontHeight - majorLinePaddingBottom
    let minorLineHeight = frame.height - fontHeight - minorLinePaddingBottom
    let stride = widthPerSecond / CGFloat(linesPerSecond)
    let textY = frame.height - fontHeight
    let textAttr = [NSAttributedString.Key.foregroundColor: labelColor,
                    NSAttributedString.Key.font: font ]

    context.setShouldAntialias(false)
    context.setAlpha(1.0)
    context.setStrokeColor(lineColor.cgColor)

    var sec = timeRange.lowerBound
    var x = rect.minX - labelPaddingLeft
    while (sec < timeRange.upperBound) {
      context.setLineWidth(majorLineWidth)
      context.move(to: CGPoint(x: x, y: 0))
      context.addLine(to: CGPoint(x: x, y: majorLineHeight))

      let text = getTimeString(seconds: sec)
      text.draw(at: CGPoint(x: x + labelPaddingLeft, y: textY), withAttributes: textAttr)
      sec += 1

      (0..<linesPerSecond).forEach { (i) in
        x += stride
        context.setLineWidth(minorLineWidth)
        context.move(to: CGPoint(x: x, y: 0))
        context.addLine(to: CGPoint(x: x, y: minorLineHeight))
      }
    }
    context.strokePath()
  }

  private func getTimeString(seconds: Int) -> String {
    let hours = seconds / 3600
    let min = seconds / 60
    let sec = seconds % 60
    if hours == 0 {
      return String(format: "%02d:%02d", min, sec)
    } else {
      return String(format: "%d:%02d:%02d", hours, min, sec)
    }
  }
}
