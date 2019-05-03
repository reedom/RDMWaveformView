//
//  RDMWaveformCursor.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/04/25.
//

import UIKit

public class RDMWaveformCursor: UIView {
  public static let defaultCursorColor = UIColor(red: 52/255, green: 120/255, blue: 245/255, alpha: 1)

  open var cursorColor = defaultCursorColor {
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
      NSLog("RDMCenterGuide failed to get graphics context")
      return
    }

    context.setFillColor(cursorColor.cgColor)
    context.setStrokeColor(cursorColor.cgColor)

    context.fillEllipse(in: CGRect(x: 0, y: 0, width: frame.width, height: 4))
    context.fillEllipse(in: CGRect(x: 0, y: frame.height - 4, width: rect.width, height: 4))
    context.fill(CGRect(x: 0, y: 2, width: frame.width, height: frame.height - 4))
  }
}
