//
//  RDMWaveformMarker.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/04/22.
//

import UIKit

open class RDMWaveformMarkerView: UIView {
  public let uuid: String
  public let touchRect: CGRect
  public let markerColor: UIColor
  public let markerRect: CGRect
  public let markerLineWidth: CGFloat

  public weak var delegate: RDMWaveformMarkerViewDelegate?

  private var touchView: UIView!

  public required init?(coder aDecoder: NSCoder) {
    fatalError("call RDMWaveformMarkerView(uuid, position) instead.")
  }

  public init(uuid: String,
              touchRect: CGRect,
              markerColor: UIColor,
              markerRect: CGRect,
              markerLineWidth: CGFloat,
              frame: CGRect = CGRect.zero) {
    self.uuid = uuid
    self.touchRect = touchRect
    self.markerColor = markerColor
    self.markerRect = markerRect
    self.markerLineWidth = markerLineWidth
    super.init(frame: frame)
    setup()
  }

  private func setup() {
    backgroundColor = UIColor.transparent
    contentMode = .redraw

    touchView = UIView(frame: touchRect)
    addSubview(touchView)
    touchView.backgroundColor = UIColor.transparent

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    touchView.addGestureRecognizer(tapGesture)
    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
    touchView.addGestureRecognizer(panGesture)
  }

  @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
    delegate?.waveformMarkerView?(self, didTap: uuid)
  }

  @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
//..     print("\(recognizer.state.rawValue) \(recognizer.location(in: superview).y)")
    switch recognizer.state {
    case .began:
      delegate?.waveformMarkerView?(self, willBeginDrag: uuid)
    case .ended, .cancelled:
      delegate?.waveformMarkerView?(self, didEndDrag: uuid)
    case .changed:
      delegate?.waveformMarkerView?(self, didDrag: uuid, x: recognizer.location(in: superview).x)
    default:
      return
    }
  }

  override open func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext() else {
      NSLog("RDMCenterGuide failed to get graphics context")
      return
    }

    context.beginPath()
    context.move(to: CGPoint(x: markerRect.midX, y: markerRect.maxY))
    context.addLine(to: CGPoint(x: markerRect.minX, y: markerRect.minY))
    context.addLine(to: CGPoint(x: markerRect.maxX, y: markerRect.minY))
    context.closePath()

    context.setFillColor(markerColor.cgColor)
    context.fillPath()

    context.setLineWidth(markerLineWidth)
    context.setStrokeColor(markerColor.cgColor)

    context.move(to: CGPoint(x: markerRect.midX, y: markerRect.maxY))
    context.addLine(to: CGPoint(x: markerRect.midX, y: bounds.maxY))
    context.strokePath()
  }
}

@objc public protocol RDMWaveformMarkerViewDelegate: NSObjectProtocol {
  @objc optional func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, didTap uuid: String)
  @objc optional func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, willBeginDrag uuid: String)
  @objc optional func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, didDrag uuid: String, x: CGFloat)
  @objc optional func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, didEndDrag uuid: String)
}
