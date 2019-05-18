//
//  RDMWaveformMarkersController.swift
//  FBSnapshotTestCase
//
//  Created by HANAI Tohru on 2019/05/01.
//

/// `RDMWaveformMarkersController` holds a number of `RDMWaveformMarker` instances
/// and is responsible to find and update any of them and also it notifies any
/// actions upon the markers.
open class RDMWaveformMarkersController: NSObject {
  /// MARK: - Properties

  /// The delegate of this object.
  open weak var delegate: RDMWaveformMarkersControllerDelegate?

  /// A list of `RDMWaveformMarkersControllerDelegate`.
  ///
  /// The observers will be notified as same as the `delegate`.
  /// The only difference is that `observers` is only available for internal classes
  /// in this package.
  private var observers = Set<WeakDelegateRef<RDMWaveformMarkersControllerDelegate>>()

  /// Under loading mode, `RDMWaveformMarkersController` suppresses notifications.
  private var loading = false

  /// A collection of `RDMWaveformMarker`.
  private var _markers = RDMWaveformMarkers()
  /// An iterator of the `RDMWaveformMarker` collection.
  /// The collection is sorted by `RDMWaveformMarker.time` ascending order.
  public var markers: IndexingIterator<[RDMWaveformMarker]> {
    return _markers.makeIterator()
  }
  /// Indicates whether the user is dragging a marker.
  public private(set) var dragging: Bool = false
}

/// MARK: - Updating markers

extension RDMWaveformMarkersController {
  @discardableResult open func add(_ marker: RDMWaveformMarker) -> Bool {
    guard
      marker.delegate == nil,
      _markers.findExact(marker.time) == nil,
      !_markers.contains(uuid: marker.uuid)
      else { return false }

    marker.delegate = self
    _markers.add(marker)
    observers.forEach({ $0.value?.waveformMarkersController?(self, didAdd: marker)})
    if !loading {
      delegate?.waveformMarkersController?(self, didAdd: marker)
    }
    return true
  }

  @discardableResult open func add(at time: TimeInterval, data: Data? = nil) -> RDMWaveformMarker? {
    return add(at: time, skip: false, data: data)
  }

  @discardableResult open func add(at time: TimeInterval, skip: Bool? = true, data: Data? = nil) -> RDMWaveformMarker? {
    guard _markers.findExact(time) == nil else { return nil }
    let marker = RDMWaveformMarker(time: time, data: data)
    marker.delegate = self
    _markers.add(marker)

    observers.forEach({ $0.value?.waveformMarkersController?(self, didAdd: marker)})
    if !loading {
      delegate?.waveformMarkersController?(self, didAdd: marker)
    }
    return marker
  }

  @discardableResult open func remove(_ marker: RDMWaveformMarker) -> Bool {
    guard _markers.remove(marker) else { return false }

    marker.delegate = nil
    observers.forEach({ $0.value?.waveformMarkersController?(self, didRemove: marker)})
    if !loading {
      delegate?.waveformMarkersController?(self, didRemove: marker)
    }
    return true
  }

  open func removeAll() {
    for marker in markers {
      marker.delegate = nil
    }
    _markers.removeAll()
    observers.forEach({ $0.value?.waveformMarkersControllerDidRemoveAllMarkers?(self)})
    delegate?.waveformMarkersControllerDidRemoveAllMarkers?(self)
  }

  open func replaceWith(_ markers: [RDMWaveformMarker]) {
    loading = true
    defer { loading = false }

    for updated in markers {
      if let current = _markers.find(uuid: updated.uuid) {
        if current.updatedAt < updated.updatedAt {
          current.copyPropertiesFrom(updated)
        } else {
        }
      } else {
        add(updated)
      }
    }

    for marker in _markers.makeIterator() {
      guard !markers.contains(where: { $0.uuid == marker.uuid }) else { continue }
      remove(marker)
    }
  }
}

/// MARK: - Finding markers

extension RDMWaveformMarkersController {
  /// Find a maker by `uuid`.
  open func find(uuid: String) -> RDMWaveformMarker? {
    return _markers.find(uuid: uuid)
  }

  /// Look up any marker that places right before `time`.
  open func findBefore(_ time: TimeInterval) -> RDMWaveformMarker? {
    return _markers.findBefore(time)
  }

  /// Look up any marker that places right after `time`.
  open func findAfter(_ time: TimeInterval) -> RDMWaveformMarker? {
    return _markers.findAfter(time)
  }

  /// Look up any marker that places right after `time`.
  open func findExact(_ time: TimeInterval) -> RDMWaveformMarker? {
    return _markers.findExact(time)
  }
}

/// MARK: - Dragging support
extension RDMWaveformMarkersController {
  func beginDrag(_ marker: RDMWaveformMarker) {
    dragging = true
    delegate?.waveformMarkersController?(self, willBeginDrag: marker)
  }

  func endDrag(_ marker: RDMWaveformMarker, removing: Bool) {
    dragging = false
    delegate?.waveformMarkersController?(self, didEndDrag: marker, removing: removing)
  }
}

/// MARK: - RDMWaveformMarkerDelegate

extension RDMWaveformMarkersController: RDMWaveformMarkerDelegate {
  func markerDidUpdateTime(_ marker: RDMWaveformMarker) {
    _markers.updateOrderIfNeeded(updated: marker)

    observers.forEach({ $0.value?.waveformMarkersController?(self, didUpdateTime: marker)})
    if !loading {
      delegate?.waveformMarkersController?(self, didUpdateTime: marker)
    }
  }

  func markerDidUpdateData(_ marker: RDMWaveformMarker) {
    observers.forEach({ $0.value?.waveformMarkersController?(self, didUpdateData: marker)})
    if !loading {
      delegate?.waveformMarkersController?(self, didUpdateData: marker)
    }
  }
}

extension RDMWaveformMarkersController {
  func subscribe(_ delegate: RDMWaveformMarkersControllerDelegate) {
    observers.insert(WeakDelegateRef(value: delegate))
  }

  func unsubscribe(_ delegate: RDMWaveformMarkersControllerDelegate) {
    while let index = observers.firstIndex(where: { (ref) -> Bool in
      guard let val = ref.value else { return true }
      return val.hash == delegate.hash
    }) {
      observers.remove(at: index)
    }
  }
}

/// MARK: - RDMWaveformMarkersControllerDelegate definition

@objc public protocol RDMWaveformMarkersControllerDelegate: NSObjectProtocol {
  /// Tells the delegate when a new marker is added to the controller.
  ///
  /// - Parameter controller: The event source.
  /// - Parameter marker: The subject.
  @objc optional func waveformMarkersController(_ controller: RDMWaveformMarkersController, didAdd marker: RDMWaveformMarker)
  /// Tells the delegate when the user starts dragging a marker.
  ///
  /// - Parameter controller: The event source.
  /// - Parameter marker: The subject.
  @objc optional func waveformMarkersController(_ controller: RDMWaveformMarkersController, willBeginDrag marker: RDMWaveformMarker)
  /// Tells the delegate when dragging ends.
  ///
  /// - Parameter controller: The event source.
  /// - Parameter marker: The subject.
  /// - Parameter removing: True if the marker is about to be removing.
  @objc optional func waveformMarkersController(_ controller: RDMWaveformMarkersController, didEndDrag marker: RDMWaveformMarker, removing: Bool)
  /// Tells the delegate when the user changed the time of a marker, by dragging or tapping.
  ///
  /// - Parameter controller: The event source.
  /// - Parameter marker: The subject.
  @objc optional func waveformMarkersController(_ controller: RDMWaveformMarkersController, didUpdateTime marker: RDMWaveformMarker)
  /// Tells the delegate when the user changed `RDMWaveformMarker.data`
  ///
  /// - Parameter controller: The event source.
  /// - Parameter marker: The subject.
  @objc optional func waveformMarkersController(_ controller: RDMWaveformMarkersController, didUpdateData marker: RDMWaveformMarker)
  /// Tells the delegate when the user removed a `RDMWaveformMarker`
  ///
  /// - Parameter controller: The event source.
  /// - Parameter marker: The subject.
  @objc optional func waveformMarkersController(_ controller: RDMWaveformMarkersController, didRemove marker: RDMWaveformMarker)
  /// Tells the delegate when the user removed all of `RDMWaveformMarker`
  ///
  /// - Parameter controller: The event source.
  @objc optional func waveformMarkersControllerDidRemoveAllMarkers(_ controller: RDMWaveformMarkersController)
}

/// MARK: - RDMWaveformMarkers

/// `RDMWaveformMarkers` holds a collection of `RDMWaveformMarker`, sorted by
/// `RDMWaveformMarker.time` ascending order.
private class RDMWaveformMarkers {
  private var markers = [RDMWaveformMarker]()

  func add(_ marker: RDMWaveformMarker) {
    if let pos = markers.firstIndex(where: { marker.time <= $0.time }) {
      markers.insert(marker, at: pos)
    } else {
      markers.append(marker)
    }
  }

  func remove(_ marker: RDMWaveformMarker) -> Bool {
    if let pos = markers.firstIndex(where: { $0.uuid == marker.uuid }) {
      markers.remove(at: pos)
      return true
    }
    return false
  }

  func removeAll() {
    markers.removeAll()
  }

  func updateOrderIfNeeded(updated marker: RDMWaveformMarker) {
    guard let pos = markers.firstIndex(where: { $0.uuid == marker.uuid }) else { return }

    var valid = true
    if 0 < pos && marker.time < markers[pos-1].time {
      valid = false
    } else if pos + 1 < markers.count  && markers[pos+1].time < marker.time {
      valid = false
    }

    if !valid {
      markers.remove(at: pos)
      add(marker)
    }
  }

  func contains(uuid: String) -> Bool {
    return markers.firstIndex(where: { $0.uuid == uuid }) != nil
  }

  func makeIterator() -> IndexingIterator<[RDMWaveformMarker]> {
    return markers.makeIterator()
  }

  func find(uuid: String) -> RDMWaveformMarker? {
    return markers.first(where: { $0.uuid == uuid })
  }

  func findBefore(_ time: TimeInterval) -> RDMWaveformMarker? {
    if let pos = markers.firstIndex(where: { time <= $0.time }) {
      return 0 < pos ? markers[pos-1] : nil
    } else if !markers.isEmpty {
      return markers.last!
    } else {
      return nil
    }
  }

  func findAfter(_ time: TimeInterval) -> RDMWaveformMarker? {
    return markers.first(where: { time < $0.time })
  }

  func findExact(_ time: TimeInterval) -> RDMWaveformMarker? {
    if let pos = markers.firstIndex(where: { time <= $0.time }) {
      if time.isEqual(to: markers[pos].time) {
        return markers[pos]
      } else if 0 < pos && time.isEqual(to: markers[pos-1].time) {
        return markers[pos-1]
      }
    }
    return nil
  }
}
