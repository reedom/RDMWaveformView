//
//  RDMWaveformTimeGuageView.swift
//  music player
//
//  Created by HANAI Tohru on 4/14/19.
//  Copyright © 2019 reedom. All rights reserved.
//

import Foundation
import UIKit

public class RDMWaveformTimeGuageView: UIView {
  var widthPerSecond: CGFloat = 100
  var linesPerSecond: Int = 4
  var lineColor = UIColor(red: 88/255, green: 88/255, blue: 88/255, alpha: 1)

  var font = UIFont(name: "Menlo", size: 10)
  let fontColor = UIColor(red: 88/255, green: 88/255, blue: 88/255, alpha: 1)

  override public func draw(_ rect: CGRect) {
    let startRendering = Date()
    guard 0 < widthPerSecond, 0 < linesPerSecond, let font = font else { return }

    let fontHeight = font.lineHeight
    let lineHeight = frame.height - fontHeight - 1
    let stride = widthPerSecond / CGFloat(linesPerSecond)

    let textAttr = [NSAttributedString.Key.foregroundColor: fontColor,
                    NSAttributedString.Key.font: font ]

    var sec = 0
    var x: CGFloat = 0
    let end = rect.maxX
    while (x < end) {
      let rect = CGRect(x: x, y: 0, width: 1, height: lineHeight)
      UIBezierPath(rect: rect).fill()

      let text = getTimeString(seconds: sec)
      text.draw(at: CGPoint(x: x, y: frame.height - fontHeight), withAttributes: textAttr)
      sec += 1

      (0..<linesPerSecond).forEach { (i) in
        x += stride
        let rect = CGRect(x: x, y: 0, width: 0.5, height: lineHeight - 4)
        UIBezierPath(rect: rect).fill()
      }
    }
    let endRendering = Date()
     NSLog("Guage rendering done, took %0.3f seconds", endRendering.timeIntervalSince(startRendering))
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
