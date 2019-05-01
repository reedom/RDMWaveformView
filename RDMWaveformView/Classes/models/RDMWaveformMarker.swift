//
//  RDMWaveformMarker.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/04/22.
//

public class RDMWaveformMarker: NSObject {
  public let uuid: String

  public var time: TimeInterval {
    didSet {
      delegate?.markerDidUpdateTime(self)
    }
  }

  public var data: Data? {
    didSet {
      delegate?.markerDidUpdateData(self)
    }
  }

  weak var delegate: RDMWaveformMarkerDelegate?

  public init(uuid: String, time: TimeInterval, data: Data? = nil) {
    self.uuid = uuid
    self.time = time
    self.data = data
  }

  public init(time: TimeInterval, data: Data? = nil) {
    self.uuid = UUID().uuidString
    self.time = time
    self.data = data
  }
}

protocol RDMWaveformMarkerDelegate: class {
  func markerDidUpdateTime(_ marker: RDMWaveformMarker)
  func markerDidUpdateData(_ marker: RDMWaveformMarker)
}
