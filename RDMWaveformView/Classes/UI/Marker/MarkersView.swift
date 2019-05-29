//
//  MarkersView.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/20.
//

import UIKit

open class MarkersView: UIView {
  public static let defaultMarkerColor = UIColor(red: 248/255, green: 206/255, blue: 70/255, alpha: 1)
  public static let defaultMarkerTouchColor = UIColor(red: 218/255, green: 18/255, blue: 18/255, alpha: 1)

  // MARK: - Maker properties

  /// The size of invisible UI responsive area where the user taps and drags.
  /// The size also affects the height of `MarkersView`
  open var markerTouchSize = CGSize(width: 46, height: 46)
  /// The size of a marker's visual representation triangle.
  open var markerSize = CGSize(width: 8, height: 12)
  /// The color of a marker's triangle.
  open var markerColor = defaultMarkerColor
  /// The color of a marker's triangle.
  open var markerTouchColor = defaultMarkerTouchColor
  /// The color of a marker's vertical line.
  open var markerLineColor = defaultMarkerColor
  /// The width of a marker's vertical line.
  open var markerLineWidth: CGFloat = 0.3
  /// The height of a marker's vertical line.
  open var markerLineHeight: CGFloat = 0
  /// Indicates whether the user can move a marker by dragging.
  open var draggable = true
  /// Indicates whether `MarkersView` shows `+` button that
  /// enables the user to add a marker by tapping it.
  open var showAddMarkerButton = false {
    didSet { setNeedsLayout() }
  }

  /// `MarkersController` instance.
  ///
  /// One or more views can share the same instance so that all the views
  /// can render and take effect its markers.
  open var markersController: MarkersController? {
    willSet {
      markersController?.unsubscribe(self)
      markerViews.values.forEach({ $0.removeFromSuperview() })
    }
    didSet {
      markersController?.subscribe(self)
      setNeedsLayout()
    }
  }

  // MARK: - Properties to work with `RDMScrollableWaveformView`

  /// The current value of `RDMScrollableWaveformView.contentOffset.x`.
  open var contentOffset: CGFloat = 0 {
    didSet { updateAddButtonPosition() }
  }
  /// Total duration of the current track.
  open var duration: TimeInterval = 0 {
    didSet { setNeedsLayout() }
  }
  /// The current time that `MarkersController` focuses at.
  open var currentTime: TimeInterval = 0

  // MARK: - Properties to support marker dragging

  /// A type that represents the current dragging target.
  private struct DraggingMarker {
    let uuid: String
    let x: CGFloat

    func copy(with x: CGFloat) -> DraggingMarker {
      return DraggingMarker(uuid: uuid, x: x)
    }
  }
  /// The current dragging target.
  private var draggingMarker: DraggingMarker?

  // MARK: - Marker

  /// A collection of `MarkerView`, each of them is a
  /// visual representation of a `Marker`.
  private var markerViews = [String: MarkerView]()

  // MARK: - Private properties

  /// Calculates the rectangle of an entire marker.
  private var markerRect: CGRect {
    return CGRect(origin: CGPoint.zero, size: markerSize)
      .offsetBy(dx: (touchRect.maxX - markerSize.width) / 2,
                dy: touchRect.height / 4)
  }

  /// Calculates the rectangle of a marker's touching area.
  private var touchRect: CGRect {
    return CGRect(origin: CGPoint.zero, size: markerTouchSize)
  }

  // MARK: - Subview

  /// `+` button
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
extension MarkersView {
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
        let markerView = MarkerView(uuid: marker.uuid,
                                    touchRect: touchRect,
                                    markerColor: markerColor,
                                    markerTouchColor: markerTouchColor,
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

  /// Calculates the actual rectangle of a marker.
  private func markerFrame(from marker: Marker) -> CGRect {
    guard 0 < bounds.width, 0 < duration else { return CGRect.zero }

    let progress = marker.time / duration
    return CGRect(x: bounds.width * CGFloat(progress) - markerTouchSize.width / 2,
                  y: 0,
                  width: markerTouchSize.width,
                  height: markerLineHeight)
  }

  /// Creates and adds specifiec number of `MarkerView` for their conterparts.
  private func addMarkerViews(markers: [Marker]) {
    markers.forEach({ (marker) in
      guard markerViews[marker.uuid] == nil else {
        debugPrint("MarkersView.addMarkerViews: markerView has already been created")
        return
      }
      let markerView = MarkerView(uuid: marker.uuid,
                                  touchRect: touchRect,
                                  markerColor: markerColor,
                                  markerTouchColor: markerTouchColor,
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

  /// Updates a `Marker`'s position.
  private func updateMarkerView(marker: Marker) {
    guard let markerView = markerViews[marker.uuid] else {
      debugPrint("MarkersView.updateMarkerView: markerView not found")
      return
    }

    markerView.frame = markerFrame(from: marker)
  }

  /// Removes a `Marker`.
  ///
  /// - Parameter marker: a marker to be removed.
  private func removeMarkerView(marker: Marker) {
    guard let markerView = markerViews.removeValue(forKey: marker.uuid) else {
      debugPrint("MarkersView.removeMarkerView: markerView not found")
      return
    }
    markerView.delegate = nil
    markerView.removeFromSuperview()
  }
}

// MARK: - `MarkersControllerDelegate`

extension MarkersView: MarkersControllerDelegate {
  public func markersController(_ controller: MarkersController, didAdd marker: Marker) {
    addMarkerViews(markers: [marker])
  }

  public func markersController(_ controller: MarkersController, didUpdateTime marker: Marker) {
    updateMarkerView(marker: marker)
  }

  public func markersController(_ controller: MarkersController, didRemove marker: Marker) {
    removeMarkerView(marker: marker)
  }

  public func markersControllerDidRemoveAllMarkers(_ controller: MarkersController) {
    while !markerViews.isEmpty {
      let (_, markerView) = markerViews.popFirst()!
      markerView.delegate = nil
      markerView.removeFromSuperview()
    }
  }
}

// MARK: - support addMarkerButton

extension MarkersView {
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

// MARK: - MarkerViewDelegate

extension MarkersView: MarkerViewDelegate {
  public func markerView(_ markerView: MarkerView, didTap uuid: String) {

  }

  public func markerView(_ markerView: MarkerView, willBeginDrag uuid: String, point: CGPoint) {
    guard draggable else { return }
    if let marker = markersController?.find(uuid: uuid) {
      draggingMarker = DraggingMarker(uuid: uuid, x: point.x)
      markersController?.beginDrag(marker)
    }
  }

  public func markerView(_ markerView: MarkerView, didDrag uuid: String, point: CGPoint) {
    guard draggable else { return }
    if draggingMarker != nil {
      draggingMarker = DraggingMarker(uuid: uuid, x: point.x)
    }

    // If the user drags the marker far above this view, prepare for removing the marker.
    if let markerView = markerViews[uuid] {
      markerView.layer.opacity = (0 <= point.y) ? 1 : 0
    }

    updateMakerTime(uuid, point.x)
  }

  public func markerView(_ markerView: MarkerView, didEndDrag uuid: String, point: CGPoint) {
    guard draggable else { return }
    draggingMarker = nil
    let removing = point.y < 0
    if let marker = markersController?.find(uuid: uuid) {
      markersController?.endDrag(marker, removing: removing)
    }

    // Remove the marker If the user drops the marker far above this view.
    if removing {
      guard let marker = markersController?.find(uuid: uuid) else { return }
      markersController?.remove(marker)
    }
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

