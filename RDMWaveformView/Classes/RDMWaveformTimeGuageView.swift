//
//  RDMWaveformTimeGuageView.swift
//  music player
//
//  Created by HANAI Tohru on 4/14/19.
//  Copyright © 2019 reedom. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import SparseRanges

public class RDMWaveformTimeGuageView: UIView {
  public var marginLeft: CGFloat = 0
  public var labelPaddingLeft: CGFloat = -2
  public var areaHeight: CGFloat = 22
  public var lineHeight: CGFloat = 10
  public var widthPerSecond: CGFloat = 100
  public var linesPerSecond: Int = 4
  public var font: UIFont = UIFont(name: "Menlo", size: 12)!
  public var lineColor: UIColor = UIColor(red: 88/255, green: 88/255, blue: 88/255, alpha: 1)
  public var fontColor: UIColor = UIColor(red: 88/255, green: 88/255, blue: 88/255, alpha: 1)

  private var renderedTimeRange = SparseCountableRange<Int>()
  private var timeRanges = [CountableRange<Int>]()

  open func reset() {
    // TODO
  }

  public func refresh() {
    renderedTimeRange.removeAll()
  }

  public func add(viewRange: CountableRange<Int>) {
    if let gaps = renderedTimeRange.gaps(timeRangeFrom(viewRange: viewRange)) {
      gaps.forEach { (timeRange) in
        print("gap: \(timeRange)")
        renderedTimeRange.add(timeRange)
        if 0 < timeRange.upperBound {
          timeRanges.append(timeRange)
          let rect = rectFrom(timeRange: timeRange)
          setNeedsDisplay(rect.insetBy(dx: -2, dy: 0))
          print("setNeedsDisplay(\(rect.insetBy(dx: -2, dy: 0))")
        }
      }
    }
  }

  private func timeRangeFrom(viewRange: CountableRange<Int>) -> CountableRange<Int> {
    let sec1 = Int(floor(CGFloat(viewRange.lowerBound) / widthPerSecond))
    let sec2 = Int(floor(CGFloat(viewRange.upperBound) / widthPerSecond))
    return max(0, sec1)..<max(0, sec2)
  }

  private func rectFrom(timeRange: CountableRange<Int>) -> CGRect {
    let x = CGFloat(timeRange.lowerBound) * widthPerSecond + marginLeft
    let width = CGFloat(timeRange.count) * widthPerSecond
    return CGRect(x: x, y: 0, width: width, height: frame.height)
  }

  override public func draw(_ rect: CGRect) {
    guard
      0 < areaHeight,
      0 < lineHeight,
      0 < widthPerSecond,
      0 < linesPerSecond else { return }

    guard let context = UIGraphicsGetCurrentContext() else {
      print("RDMWaveformView failed to get graphics context")
      return
    }
    timeRanges.forEach { (timeRange) in
      drawGuage(context: context, timeRange: timeRange)
    }
    timeRanges.removeAll()
  }

  private func drawGuage(context: CGContext, timeRange: CountableRange<Int>) {
    let rect = rectFrom(timeRange: timeRange)
    print("drawGuage: \(rect)")
    let fontHeight = font.lineHeight
    let lineHeight = frame.height - fontHeight - 1
    let stride = widthPerSecond / CGFloat(linesPerSecond)

    let textAttr = [NSAttributedString.Key.foregroundColor: fontColor,
                    NSAttributedString.Key.font: font ]

    context.setShouldAntialias(false)
    context.setAlpha(1.0)
    context.setStrokeColor(lineColor.cgColor)

    var sec = timeRange.lowerBound
    var x = rect.minX - labelPaddingLeft
    while (x < rect.maxX) {
      context.setLineWidth(1)
      context.move(to: CGPoint(x: x, y: 0))
      context.addLine(to: CGPoint(x: x, y: lineHeight))

      let text = getTimeString(seconds: sec)
      text.draw(at: CGPoint(x: x + labelPaddingLeft, y: frame.height - fontHeight), withAttributes: textAttr)
      sec += 1

      (0..<linesPerSecond).forEach { (i) in
        x += stride
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: x, y: 0))
        context.addLine(to: CGPoint(x: x, y: lineHeight - 2))
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
