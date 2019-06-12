//
//  MarkersController.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/20.
//

/// `MarkersController` holds a number of `Marker` instances
/// and is responsible to find and update any of them and also it notifies any
/// actions upon the markers.
open class MarkersController: NSObject {
  /// MARK: - Properties

  /// The delegate of this object.
  open weak var delegate: MarkersControllerDelegate?

  /// A list of `MarkersControllerDelegate`.
  ///
  /// The observers will be notified as same as the `delegate`.
  /// The only difference is that `observers` is only available for internal classes
  /// in this package.
  private var observers = Set<WeakDelegateRef<MarkersControllerDelegate>>()

  /// Under loading mode, `MarkersController` suppresses notifications.
  private var loading = false

  /// A collection of `Marker`.
  private var _markers = Markers()
  /// An iterator of the `Marker` collection.
  /// The collection is sorted by `Marker.time` ascending order.
  public var markers: IndexingIterator<[Marker]> {
    return _markers.makeIterator()
  }

  /// THe current time.
  public var currentTime: TimeInterval = 0 {
    didSet {
      if !surroundMarker.contains(time: currentTime) {
        updateSurroundMarker()
      }
    }
  }
  /// Markers that surround `currentTime`
  public private(set) var surroundMarker = SurroundMarker(upperBound: nil, lowerBound: nil)

  /// Indicates whether the user is dragging a marker.
  public private(set) var dragging: Bool = false
}

/// MARK: - Updating markers

extension MarkersController {
  @discardableResult open func add(_ marker: Marker) -> Bool {
    guard
      marker.delegate == nil,
      _markers.find(exact: marker.time) == nil,
      !_markers.contains(uuid: marker.uuid)
      else { return false }
    marker.delegate = self
    _markers.add(marker)

    if surroundMarker.contains(time: marker.time) {
      updateSurroundMarker()
    }

    observers.forEach({ $0.value?.markersController?(self, didAdd: marker)})
    if !loading {
      delegate?.markersController?(self, didAdd: marker)
    }
    return true
  }

  @discardableResult open func add(at time: TimeInterval, data: Data? = nil) -> Marker? {
    return add(at: time, skip: false, data: data)
  }

  @discardableResult open func add(at time: TimeInterval, skip: Bool = true, data: Data? = nil) -> Marker? {
    guard _markers.find(exact: time) == nil else { return nil }
    let marker = Marker(time: time, data: data, skip: skip)
    marker.delegate = self
    _markers.add(marker)

    if surroundMarker.contains(time: marker.time) {
      updateSurroundMarker()
    }

    observers.forEach({ $0.value?.markersController?(self, didAdd: marker)})
    if !loading {
      delegate?.markersController?(self, didAdd: marker)
    }
    return marker
  }

  @discardableResult open func remove(_ marker: Marker) -> Bool {
    guard _markers.remove(marker) else { return false }

    marker.delegate = nil

    if surroundMarker.relates(with: marker) {
      updateSurroundMarker()
    }

    observers.forEach({ $0.value?.markersController?(self, didRemove: marker)})
    if !loading {
      delegate?.markersController?(self, didRemove: marker)
    }
    return true
  }

  open func removeAll() {
    for marker in markers {
      marker.delegate = nil
    }
    _markers.removeAll()
    updateSurroundMarker()
    observers.forEach({ $0.value?.markersControllerDidRemoveAllMarkers?(self)})
    delegate?.markersControllerDidRemoveAllMarkers?(self)
  }

  open func replaceWith(_ markers: [Marker]) {
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

extension MarkersController {
  open var isEmpty: Bool {
    return _markers.isEmpty
  }

  /// Find a maker by `uuid`.
  open func find(uuid: String) -> Marker? {
    return _markers.find(uuid: uuid)
  }

  /// Look up any marker that places right before `time`.
  open func find(before time: TimeInterval, excludeSkip: Bool) -> Marker? {
    return _markers.find(before: time, excludeSkip: excludeSkip)
  }

  /// Look up any marker that places right after `time`.
  open func find(after time: TimeInterval, excludeSkip: Bool) -> Marker? {
    return _markers.find(after: time, excludeSkip: excludeSkip)
  }

  /// Look up any marker that places right after `time`.
  open func find(exact time: TimeInterval) -> Marker? {
    return _markers.find(exact: time)
  }

  open func find(surrounding time: TimeInterval) -> SurroundMarker {
    if _markers.isEmpty {
      return SurroundMarker.empty
    }

    let lowerBound: Marker?
    let upperBound = _markers.find(after: currentTime, excludeSkip: false)
    if upperBound != nil {
      lowerBound = _markers.find(before: upperBound!.time, excludeSkip: false)
    } else {
      lowerBound = _markers.find(before: currentTime + 1, excludeSkip: false)
    }
    return SurroundMarker(upperBound: upperBound, lowerBound: lowerBound)
  }
}

extension MarkersController {
  func updateSurroundMarker() {
    if _markers.isEmpty {
      if !surroundMarker.isEmpty {
        surroundMarker = SurroundMarker(upperBound: nil, lowerBound: nil)
        observers.forEach({ $0.value?.markersController?(self, didUpdateSurroundMarkers: surroundMarker) })
        if !loading {
          delegate?.markersController?(self, didUpdateSurroundMarkers: surroundMarker)
        }
      }
      return
    }

    surroundMarker = find(surrounding: currentTime)
    observers.forEach({ $0.value?.markersController?(self, didUpdateSurroundMarkers: surroundMarker) })
    if !loading {
      delegate?.markersController?(self, didUpdateSurroundMarkers: surroundMarker)
    }
  }
}

/// MARK: - Dragging support
extension MarkersController {
  func beginDrag(_ marker: Marker) {
    dragging = true
    delegate?.markersController?(self, willBeginDrag: marker)
  }

  func endDrag(_ marker: Marker, removing: Bool) {
    dragging = false
    delegate?.markersController?(self, didEndDrag: marker, removing: removing)
  }
}

/// MARK: - MarkerDelegate

extension MarkersController: MarkerDelegate {
  func markerDidUpdateTime(_ marker: Marker) {
    _markers.updateOrderIfNeeded(updated: marker)

    if surroundMarker.relates(with: marker) || surroundMarker.contains(time: marker.time) {
      updateSurroundMarker()
    }

    observers.forEach({ $0.value?.markersController?(self, didUpdateTime: marker)})
    if !loading {
      delegate?.markersController?(self, didUpdateTime: marker)
    }
  }

  func markerDidUpdateData(_ marker: Marker) {
    observers.forEach({ $0.value?.markersController?(self, didUpdateData: marker)})
    if !loading {
      delegate?.markersController?(self, didUpdateData: marker)
    }
  }
}

extension MarkersController {
  func subscribe(_ delegate: MarkersControllerDelegate) {
    observers.insert(WeakDelegateRef(value: delegate))
  }

  func unsubscribe(_ delegate: MarkersControllerDelegate) {
    while let index = observers.firstIndex(where: { (ref) -> Bool in
      guard let val = ref.value else { return true }
      return val.hash == delegate.hash
    }) {
      observers.remove(at: index)
    }
  }
}

/// MARK: - Markers

/// `Markers` holds a collection of `Marker`, sorted by
/// `Marker.time` ascending order.
private class Markers {
  private var markers = [Marker]()

  var isEmpty: Bool {
    return markers.isEmpty
  }

  func add(_ marker: Marker) {
    if let pos = markers.firstIndex(where: { marker.time.isEqual(to: $0.time) || marker.time < $0.time }) {
      markers.insert(marker, at: pos)
    } else {
      markers.append(marker)
    }
  }

  func remove(_ marker: Marker) -> Bool {
    if let pos = markers.firstIndex(where: { $0.uuid == marker.uuid }) {
      markers.remove(at: pos)
      return true
    }
    return false
  }

  func removeAll() {
    markers.removeAll()
  }

  func updateOrderIfNeeded(updated marker: Marker) {
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

  func makeIterator() -> IndexingIterator<[Marker]> {
    return markers.makeIterator()
  }

  func find(uuid: String) -> Marker? {
    return markers.first(where: { $0.uuid == uuid })
  }

  func find(before time: TimeInterval, excludeSkip: Bool) -> Marker? {
    var pos: Int!
    pos = markers.firstIndex(where: { time.isEqual(to: $0.time) || time < $0.time })
    if pos == nil {
      if let marker = markers.last, marker.time < time {
        pos = markers.count
      } else {
        return nil
      }
    }

    pos -= 1
    while 0 <= pos && excludeSkip && markers[pos].skip {
      pos -= 1
    }
    return 0 <= pos ? markers[pos] : nil
  }

  func find(after time: TimeInterval, excludeSkip: Bool) -> Marker? {
    return markers.first(where: { (!excludeSkip || !$0.skip) && !time.isEqual(to: $0.time) && time < $0.time })
  }

  func find(exact time: TimeInterval) -> Marker? {
    if let pos = markers.firstIndex(where: { time.isEqual(to: $0.time) || time < $0.time }) {
      if time.isEqual(to: markers[pos].time) {
        return markers[pos]
      } else if 0 < pos && time.isEqual(to: markers[pos-1].time) {
        return markers[pos-1]
      }
    }
    return nil
  }
}
