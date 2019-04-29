//
//  RDMWaveformMarkersContainer.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/04/26.
//

import UIKit

open class RDMWaveformMarkersContainer: UIView {
  public static let defaultMarkerColor = UIColor(red: 248/255, green: 206/255, blue: 70/255, alpha: 1)

  // MARK: - Maker properties

  open var markerTouchSize = CGSize(width: 36, height: 36)
  open var markerSize = CGSize(width: 8, height: 12)
  open var markerColor = defaultMarkerColor
  open var markerLineWidth: CGFloat = 0.3
  open var markerLineHeight: CGFloat = 0

  // MARK: audio property

  open var totalSamples: Int = 0 {
    didSet { updateMarkers() }
  }

  // MARK: - Dragging a marker

  private struct DraggingMarker {
    let uuid: String
    let x: CGFloat
  }
  private var draggingMarker: DraggingMarker?

  // MARK: - Markers

  /// The samples to be highlighted in a different color
  private var _markers = [RDMWaveformMarker]()
  open var markers: [RDMWaveformMarker] {
    get {
      return _markers
    }
    set {
      _markers = newValue
      updateMarkers()
    }
  }

  // MARK: - Initialization

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    clipsToBounds = false
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    clipsToBounds = false
  }

  // MARK: - Marker management

  public func addMarker(position: Int) -> RDMWaveformMarker? {
    if markers.contains(where: { $0.position == position }) {
      return nil
    }

    let marker = RDMWaveformMarker(position: position)
    markers.append(marker)
    return marker
  }

  public func updateMarkers() {
    guard 0 < totalSamples else { return }

    let markerViews = subviews
      .filter { $0.self.isKind(of: RDMWaveformMarkerView.self) }
      .map { $0 as! RDMWaveformMarkerView }

    markerViews.forEach { (markerView) in
      if let marker = markers.first(where: { $0.uuid == markerView.uuid }) {
        markerView.frame = markerFrame(from: marker)
      } else {
        markerView.removeFromSuperview()
      }
    }

    let touchRect = CGRect(origin: CGPoint.zero, size: markerTouchSize)
    let markerRect = CGRect(origin: CGPoint.zero, size: markerSize)
      .offsetBy(dx: (touchRect.maxX - markerSize.width) / 2,
                dy: touchRect.height - markerSize.height)

    markers
      .filter { (marker) in !markerViews.contains(where: { $0.uuid == marker.uuid }) }
      .forEach { (marker) in
        let markerView = RDMWaveformMarkerView(uuid: marker.uuid,
                                               touchRect: touchRect,
                                               markerColor: markerColor,
                                               markerRect: markerRect,
                                               markerLineWidth: markerLineWidth,
                                               frame: markerFrame(from: marker))
        markerView.delegate = self
        addSubview(markerView)
        markerView.setNeedsDisplay()
    }
  }

  private func markerFrame(from marker: RDMWaveformMarker) -> CGRect {
    guard 0 < bounds.width, 0 < totalSamples else { return CGRect.zero }

    let progress = CGFloat(marker.position) / CGFloat(totalSamples)
    return CGRect(x: bounds.width * progress - markerTouchSize.width / 2,
                  y: 0,
                  width: markerTouchSize.width,
                  height: markerLineHeight)
  }
}

// MARK: - RDMWaveformMarkerViewDelegate

extension RDMWaveformMarkersContainer: RDMWaveformMarkerViewDelegate {
  public func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, didTap uuid: String) {

  }

  public func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, willBeginDrag uuid: String) {
  }

  public func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, didDrag uuid: String, x: CGFloat) {
    updateMakerPosition(uuid, x)
  }

  public func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, didEndDrag uuid: String) {
    draggingMarker = nil
  }

  public func contentOffsetDidChange(dx: CGFloat) {
    guard let draggingMarker = draggingMarker else { return }

    let x = draggingMarker.x + dx
    updateMakerPosition(draggingMarker.uuid, x)
  }

  private func updateMakerPosition(_ uuid: String, _ x: CGFloat) {
    guard let i = markers.firstIndex(where: { $0.uuid == uuid }) else { return }

    let marker = markers[i]
    let progress = max(0, min(1, x / frame.width))
    let samplePosition = Int(CGFloat(totalSamples) * progress)
    markers[i] = marker.copy(withPosition: samplePosition)
    draggingMarker = DraggingMarker(uuid: uuid, x: x)
  }
}
