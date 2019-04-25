//
//  RDMCenterGuide.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/04/25.
//

import UIKit

open class RDMCenterGuide: UIView {
  public static let defaultGuideColor = UIColor(red: 52/255, green: 120/255, blue: 245/255, alpha: 1)

  open var guideColor = defaultGuideColor
  open var markerDiameter: CGFloat = 7

  override open func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else {
      NSLog("RDMCenterGuide failed to get graphics context")
      return
    }

    context.setFillColor(guideColor.cgColor)
    context.setStrokeColor(guideColor.cgColor)

    let mx = frame.width / 2
    var rect = CGRect(x: 0, y: 0, width: markerDiameter, height: markerDiameter)
    rect = rect.offsetBy(dx: mx - rect.width / 2, dy: 0)
    context.fillEllipse(in: rect)
    rect = rect.offsetBy(dx: 0, dy: frame.height - rect.height)
    context.fillEllipse(in: rect)

    context.move(to: CGPoint(x: rect.midX, y: rect.height / 2))
    context.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
    context.strokePath()
  }
}
