//
//  RDMWaveformMarkersController.swift
//  FBSnapshotTestCase
//
//  Created by HANAI Tohru on 2019/05/01.
//

open class RDMWaveformMarkersController: NSObject {
  open weak var delegate: RDMWaveformMarkersControllerDelegate?
  private var observers = Set<WeakDelegateRef<RDMWaveformMarkersControllerDelegate>>()

  open private(set) var markers = [String: RDMWaveformMarker]()

  @discardableResult open func add(_ marker: RDMWaveformMarker) -> Bool {
    guard
      marker.delegate == nil,
      markers[marker.uuid] == nil
      else { return false }

    marker.delegate = self
    markers[marker.uuid] = marker
    observers.forEach({ $0.value?.waveformMarkersController?(self, didAdd: marker)})
    delegate?.waveformMarkersController?(self, didAdd: marker)
    return true
  }

  @discardableResult open func add(at time: TimeInterval, data: Data? = nil) -> RDMWaveformMarker {
    let marker = RDMWaveformMarker(time: time, data: data)
    marker.delegate = self
    markers[marker.uuid] = marker

    observers.forEach({ $0.value?.waveformMarkersController?(self, didAdd: marker)})
    delegate?.waveformMarkersController?(self, didAdd: marker)
    return marker
  }

  @discardableResult open func remove(_ marker: RDMWaveformMarker) -> Bool {
    guard markers.removeValue(forKey: marker.uuid) != nil else { return false }

    marker.delegate = nil
    observers.forEach({ $0.value?.waveformMarkersController?(self, didRemove: marker)})
    delegate?.waveformMarkersController?(self, didRemove: marker)
    return true
  }
}

extension RDMWaveformMarkersController: RDMWaveformMarkerDelegate {
  func markerDidUpdateTime(_ marker: RDMWaveformMarker) {
    observers.forEach({ $0.value?.waveformMarkersController?(self, didUpdatePosition: marker)})
    delegate?.waveformMarkersController?(self, didUpdatePosition: marker)
  }

  func markerDidUpdateData(_ marker: RDMWaveformMarker) {
    observers.forEach({ $0.value?.waveformMarkersController?(self, didUpdateData: marker)})
    delegate?.waveformMarkersController?(self, didUpdateData: marker)
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

@objc public protocol RDMWaveformMarkersControllerDelegate: NSObjectProtocol {
  @objc optional func waveformMarkersController(_ controller: RDMWaveformMarkersController, didAdd marker: RDMWaveformMarker)
  @objc optional func waveformMarkersController(_ controller: RDMWaveformMarkersController, didUpdatePosition marker: RDMWaveformMarker)
  @objc optional func waveformMarkersController(_ controller: RDMWaveformMarkersController, didUpdateData marker: RDMWaveformMarker)
  @objc optional func waveformMarkersController(_ controller: RDMWaveformMarkersController, didRemove marker: RDMWaveformMarker)
}
