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

  open var markerTouchSize = CGSize(width: 46, height: 46)
  open var markerSize = CGSize(width: 8, height: 12)
  open var markerColor = defaultMarkerColor
  open var markerLineColor = defaultMarkerColor
  open var markerLineWidth: CGFloat = 0.3
  open var markerLineHeight: CGFloat = 0
  open var draggable = true
  open var showAddMarkerButton = false {
    didSet { setNeedsLayout() }
  }

  private var touchRect: CGRect {
    return CGRect(origin: CGPoint.zero, size: markerTouchSize)
  }

  private var markerRect: CGRect {
    return CGRect(origin: CGPoint.zero, size: markerSize)
      .offsetBy(dx: (touchRect.maxX - markerSize.width) / 2,
                dy: touchRect.height / 4)
  }

  private lazy var addMarkerButton: UIButton = {
    let button = UIButton(type: .custom)
    addSubview(button)
    button.setTitle("＋", for: .normal)
    button.contentHorizontalAlignment = .center
    button.contentVerticalAlignment = .bottom
    button.setTitleColor(markerColor, for: .normal)
    button.addTarget(self, action: #selector(addMarker), for: .touchUpInside)
    button.isHidden = !showAddMarkerButton
    return button
  }()

  // MARK: audio property

  open var duration: TimeInterval = 0 {
    didSet { setNeedsLayout() }
  }

  // MARK: - support scrolling view

  open var currentTime: TimeInterval = 0
  open var contentOffset: CGFloat = 0 {
    didSet { updateAddButtonPosition() }
  }

  // MARK: - Dragging a marker

  private struct DraggingMarker {
    let uuid: String
    let x: CGFloat

    func copy(with x: CGFloat) -> DraggingMarker {
      return DraggingMarker(uuid: uuid, x: x)
    }
  }
  private var draggingMarker: DraggingMarker?

  // MARK: - Marker

  open var markersController: RDMWaveformMarkersController? {
    willSet {
      markersController?.unsubscribe(self)
      markerViews.values.forEach({ $0.removeFromSuperview() })
    }
    didSet {
      markersController?.subscribe(self)
      setNeedsLayout()
    }
  }

  private var markerViews = [String: RDMWaveformMarkerView]()

  // MARK: - Initialization

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    clipsToBounds = false
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    clipsToBounds = false
  }
}

// MARK: - Marker management
extension RDMWaveformMarkersContainer {
  override open func layoutSubviews() {
    guard
      0 < duration,
      let markersController = markersController
      else { return }

    // Traverse known markerViews.
    markerViews.forEach { (uuid, markerView) in
      if let marker = markersController.find(uuid: uuid) {
        // The source marker exists; update the visual position.
        markerView.frame = markerFrame(from: marker)
      } else {
        // The source marker has gone; remove the view.
        markerView.removeFromSuperview()
      }
    }

    // Create any markerViews for newly created markers as their visual representation.

    markersController.markers
      .filter { markerViews[$0.uuid] == nil }
      .forEach { (marker) in
        let markerView = RDMWaveformMarkerView(uuid: marker.uuid,
                                               touchRect: touchRect,
                                               markerColor: markerColor,
                                               markerRect: markerRect,
                                               markerLineColor: markerLineColor,
                                               markerLineWidth: markerLineWidth,
                                               frame: markerFrame(from: marker))
        markerView.delegate = self
        addSubview(markerView)
        markerViews[markerView.uuid] = markerView
        markerView.setNeedsDisplay()
    }

    if showAddMarkerButton {
      addMarkerButton.frame = CGRect(x: frame.midX - markerTouchSize.width / 2,
                                     y: 0,
                                     width: markerTouchSize.width,
                                     height: markerTouchSize.height)
      updateAddButtonPosition()
      sendSubviewToBack(addMarkerButton)
    }
  }

  private func markerFrame(from marker: RDMWaveformMarker) -> CGRect {
    guard 0 < bounds.width, 0 < duration else { return CGRect.zero }

    let progress = marker.time / duration
    return CGRect(x: bounds.width * CGFloat(progress) - markerTouchSize.width / 2,
                  y: 0,
                  width: markerTouchSize.width,
                  height: markerLineHeight)
  }

  private func addMarkerViews(markers: [RDMWaveformMarker]) {
    markers.forEach({ (marker) in
      guard markerViews[marker.uuid] == nil else {
        debugPrint("RDMWaveformMarkersContainer.addMarkerViews: markerView has already been created")
        return
      }
      let markerView = RDMWaveformMarkerView(uuid: marker.uuid,
                                             touchRect: touchRect,
                                             markerColor: markerColor,
                                             markerRect: markerRect,
                                             markerLineColor: markerLineColor,
                                             markerLineWidth: markerLineWidth,
                                             frame: markerFrame(from: marker))
      markerView.delegate = self
      addSubview(markerView)
      markerViews[markerView.uuid] = markerView
      markerView.setNeedsDisplay()
    })
  }

  private func updateMarkerView(marker: RDMWaveformMarker) {
    guard let markerView = markerViews[marker.uuid] else {
      debugPrint("RDMWaveformMarkersContainer.updateMarkerView: markerView not found")
      return
    }

    markerView.frame = markerFrame(from: marker)
  }

  private func removeMarkerView(marker: RDMWaveformMarker) {
    guard let markerView = markerViews.removeValue(forKey: marker.uuid) else {
      debugPrint("RDMWaveformMarkersContainer.removeMarkerView: markerView not found")
      return
    }
    markerView.delegate = nil
    markerView.removeFromSuperview()
  }
}

extension RDMWaveformMarkersContainer: RDMWaveformMarkersControllerDelegate {
  public func waveformMarkersController(_ controller: RDMWaveformMarkersController, didAdd marker: RDMWaveformMarker) {
    addMarkerViews(markers: [marker])
  }

  public func waveformMarkersController(_ controller: RDMWaveformMarkersController, didUpdatePosition marker: RDMWaveformMarker) {
    updateMarkerView(marker: marker)
  }

  public func waveformMarkersController(_ controller: RDMWaveformMarkersController, didUpdateData marker: RDMWaveformMarker) {
  }

  public func waveformMarkersController(_ controller: RDMWaveformMarkersController, didRemove marker: RDMWaveformMarker) {
    removeMarkerView(marker: marker)
  }
}

// MARK: - support addMarkerButton

extension RDMWaveformMarkersContainer {
  private func updateAddButtonPosition() {
    guard showAddMarkerButton else { return }
    let frame = addMarkerButton.frame
    addMarkerButton.frame = CGRect(x: contentOffset - frame.width / 2,
                                   y: frame.minY,
                                   width: frame.width,
                                   height: frame.height)
  }

  @objc private func addMarker() {
    guard
      let markersController = markersController
      else { return }
    guard !markersController.markers.contains( where: { $0.time == currentTime }) else { return }
    markersController.add(at: currentTime)
  }
}

// MARK: - RDMWaveformMarkerViewDelegate

extension RDMWaveformMarkersContainer: RDMWaveformMarkerViewDelegate {
  public func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, didTap uuid: String) {

  }

  public func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, willBeginDrag uuid: String) {
  }

  public func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, didDrag uuid: String, x: CGFloat) {
    guard draggable else { return }
    draggingMarker = DraggingMarker(uuid: uuid, x: x)
    updateMakerTime(uuid, x)
  }

  public func waveformMarkerView(_ waveformMarkerView: RDMWaveformMarkerView, didEndDrag uuid: String) {
    draggingMarker = nil
  }

  public func updateDraggingMarkerPosition(scrollDelta dx: CGFloat) {
    guard
      draggable,
      let draggingMarker = draggingMarker
      else { return }

    let x = max(0, min(frame.width, draggingMarker.x + dx))
    self.draggingMarker = draggingMarker.copy(with: x)
    updateMakerTime(draggingMarker.uuid, x)
  }

  private func updateMakerTime(_ uuid: String, _ x: CGFloat) {
    guard
      0 < duration,
      0 < frame.width,
      let marker = markersController?.find(uuid: uuid)
      else { return }

    let progress = max(0, min(1, x / frame.width))
    marker.time = TimeInterval(progress) * duration
  }
}
