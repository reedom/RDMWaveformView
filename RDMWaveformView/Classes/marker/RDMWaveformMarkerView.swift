//
//  RDMWaveformMarker.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/04/22.
//

import UIKit

open class RDMWaveformMarkerView: UIView {
  // MARK: - Properties

  public let uuid: String
  public let touchRect: CGRect
  public let markerColor: UIColor
  public let markerTouchColor: UIColor
  public let markerRect: CGRect
  public let markerLineColor: UIColor
  public let markerLineWidth: CGFloat

  public weak var delegate: RDMWaveformMarkerViewDelegate?

  private enum PressingType {
    case touch
    case pan
  }
  private var pressing = Set<PressingType>() {
    didSet {
      if pressing.isEmpty != oldValue.isEmpty {
        setNeedsDisplay()
      }
    }
  }

  // MARK: - Initialization

  public required init?(coder aDecoder: NSCoder) {
    fatalError("call RDMWaveformMarkerView(uuid, position) instead.")
  }

  public init(uuid: String,
              touchRect: CGRect,
              markerColor: UIColor,
              markerTouchColor: UIColor,
              markerRect: CGRect,
              markerLineColor: UIColor,
              markerLineWidth: CGFloat,
              frame: CGRect = CGRect.zero) {
    self.uuid = uuid
    self.touchRect = touchRect
    self.markerColor = markerColor
    self.markerTouchColor = markerTouchColor
    self.markerRect = markerRect
    self.markerLineColor = markerLineColor
    self.markerLineWidth = markerLineWidth
    super.init(frame: frame)
    setup()
  }

  private func setup() {
    backgroundColor = UIColor.transparent
    contentMode = .redraw

    let touchView = UIView(frame: touchRect)
    addSubview(touchView)
    touchView.backgroundColor = UIColor.transparent

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    touchView.addGestureRecognizer(tapGesture)
    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
    touchView.addGestureRecognizer(panGesture)
  }
}

// MARK: - UI event handlers

extension RDMWaveformMarkerView: UIGestureRecognizerDelegate {
  override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)
    pressing.insert(.touch)
  }

  override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    pressing.remove(.touch)
  }

  override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesCancelled(touches, with: event)
    pressing.remove(.touch)
  }

  @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
    delegate?.waveformMarkerView?(self, didTap: uuid)
  }

  @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
    let point = recognizer.location(in: superview)
    switch recognizer.state {
    case .began:
      pressing.insert(.pan)
      delegate?.waveformMarkerView?(self, willBeginDrag: uuid, point: point)
    case .ended, .cancelled:
      pressing.remove(.pan)
      delegate?.waveformMarkerView?(self, didEndDrag: uuid, point: point)
    case .changed:
      delegate?.waveformMarkerView?(self, didDrag: uuid, point: point)
    default:
      return
    }
  }
}

// MARK: - drawing

extension RDMWaveformMarkerView {
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

    context.setFillColor(pressing.isEmpty ? markerColor.cgColor : markerTouchColor.cgColor)
    context.fillPath()

    context.setLineWidth(markerLineWidth)
    context.setStrokeColor(pressing.isEmpty ? markerLineColor.cgColor : markerTouchColor.cgColor)

    context.move(to: CGPoint(x: markerRect.midX, y: markerRect.maxY))
    context.addLine(to: CGPoint(x: markerRect.midX, y: bounds.maxY))
    context.strokePath()
  }
}

@objc public protocol RDMWaveformMarkerViewDelegate: NSObjectProtocol {
  @objc optional func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, didTap uuid: String)
  @objc optional func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, willBeginDrag uuid: String, point: CGPoint)
  @objc optional func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, didDrag uuid: String, point: CGPoint)
  @objc optional func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, didEndDrag uuid: String, point: CGPoint)
}
