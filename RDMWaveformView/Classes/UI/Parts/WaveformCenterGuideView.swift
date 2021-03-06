//
//  CenterGuide.swift
//  WaveformView
//
//  Created by HANAI Tohru on 2019/04/25.
//

import UIKit

open class CenterGuide: UIView {
  public static let defaultGuideColor = UIColor(red: 52/255, green: 120/255, blue: 245/255, alpha: 1)

  open var guideColor = defaultGuideColor {
    didSet { setNeedsDisplay() }
  }
  open var markerDiameter: CGFloat = 7 {
    didSet { setNeedsDisplay() }
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    isUserInteractionEnabled = false
    contentMode = .redraw
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    contentMode = .redraw
  }

  override open func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else {
      NSLog("CenterGuide failed to get graphics context")
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
