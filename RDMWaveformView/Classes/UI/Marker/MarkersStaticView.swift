//
//  MarkersStaticView.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/06/13.
//

import Foundation

open class MarkersStaticView: UIView {
  public static let defaultMarkerColor = UIColor(red: 248/255, green: 206/255, blue: 70/255, alpha: 1)
  public static let defaultMarkerTouchColor = UIColor(red: 218/255, green: 18/255, blue: 18/255, alpha: 1)

  // MARK: - Maker properties

  /// The size of a marker's visual representation triangle.
  open var markerSize = CGSize(width: 8, height: 12)
  /// The color of a marker's triangle.
  open var markerColor = defaultMarkerColor
  /// The color of a marker's vertical line.
  open var markerLineColor = defaultMarkerColor
  /// The width of a marker's vertical line.
  open var markerLineWidth: CGFloat = 0.3
  /// The height of a marker's vertical line.
  open var markerLineHeight: CGFloat = 0

  /// `MarkersController` instance.
  ///
  /// One or more views can share the same instance so that all the views
  /// can render and take effect its markers.
  open var markersController: MarkersController? {
    willSet {
      markersController?.unsubscribe(self)
    }
    didSet {
      markersController?.subscribe(self)
      setNeedsLayout()
    }
  }

  /// Total duration of the current track.
  open var duration: TimeInterval = 0 {
    didSet { setNeedsLayout() }
  }

  // MARK: - Initialization

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
  }
}

extension MarkersStaticView {
  /// Calculates the actual rectangle of a marker.
  private func markerFrame(from marker: Marker) -> CGRect {
    guard 0 < bounds.width, 0 < duration else { return CGRect.zero }

    let progress = marker.time / duration
    return CGRect(x: bounds.width * CGFloat(progress) - markerSize.width / 2,
                  y: 0,
                  width: markerSize.width,
                  height: markerLineHeight)
  }
}

extension MarkersStaticView {
  override open func draw(_ rect: CGRect) {
    guard
      0 < bounds.width,
      0 < duration,
      let markers = markersController?.markers,
      let context = UIGraphicsGetCurrentContext()
      else {
        return
    }

    for marker in markers {
      let progress = marker.time / duration
      let markerRect = CGRect(x: bounds.width * CGFloat(progress) - markerSize.width / 2,
                              y: 0,
                              width: markerSize.width,
                              height: markerSize.height)
      context.beginPath()
      context.move(to: CGPoint(x: markerRect.midX, y: markerRect.maxY))
      context.addLine(to: CGPoint(x: markerRect.minX, y: markerRect.minY))
      context.addLine(to: CGPoint(x: markerRect.maxX, y: markerRect.minY))
      context.closePath()

      context.setFillColor(markerColor.cgColor)
      context.fillPath()
    }
  }
}

// MARK: - `MarkersControllerDelegate`

extension MarkersStaticView: MarkersControllerDelegate {
  public func markersController(_ controller: MarkersController, didAdd marker: Marker) {
    setNeedsDisplay()
  }

  public func markersController(_ controller: MarkersController, didUpdateTime marker: Marker) {
    setNeedsDisplay()
  }

  public func markersController(_ controller: MarkersController, didRemove marker: Marker) {
    setNeedsDisplay()
  }

  public func markersControllerDidRemoveAllMarkers(_ controller: MarkersController) {
    setNeedsDisplay()
  }
}

// MARK: - MarkerViewDelegate

extension MarkersStaticView: MarkerViewDelegate {
  public func markerView(_ markerView: MarkerView, didDrag uuid: String, point: CGPoint) {
    setNeedsDisplay()
  }

  public func markerView(_ markerView: MarkerView, didEndDrag uuid: String, point: CGPoint) {
    setNeedsDisplay()
  }
}

