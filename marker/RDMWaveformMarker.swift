//
//  RDMWaveformMarker.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/04/22.
//

/// `RDMWaveformMarker` represents a marker, which works as like a bookmark of a book.
/// With a mark, the user can jump to a specific time position to start playback, or
/// can have section-loop-playback feature.
public class RDMWaveformMarker: NSObject {
  /// A unique ID.
  public let uuid: String

  /// A time position in a track at which this marker places.
  public var time: TimeInterval {
    didSet {
      delegate?.markerDidUpdateTime(self)
    }
  }

  /// `data` can hold any kind of data that to be bind with a marker.
  public var data: Data? {
    didSet {
      delegate?.markerDidUpdateData(self)
    }
  }

  /// The delegate of this object.
  weak var delegate: RDMWaveformMarkerDelegate?

  /// Initialize the instance.
  public init(uuid: String, time: TimeInterval, data: Data? = nil) {
    self.uuid = uuid
    self.time = time
    self.data = data
  }

  /// Initialize the instance.
  public init(time: TimeInterval, data: Data? = nil) {
    self.uuid = UUID().uuidString
    self.time = time
    self.data = data
  }

  static func ==(lhs: RDMWaveformMarker, rhs: RDMWaveformMarker) -> Bool {
    return lhs.uuid == rhs.uuid
  }

  static func !=(lhs: RDMWaveformMarker, rhs: RDMWaveformMarker) -> Bool {
    return lhs.uuid != rhs.uuid
  }
}

protocol RDMWaveformMarkerDelegate: class {
  /// Tells when the user update `RDMWaveformMarker.time`.
  func markerDidUpdateTime(_ marker: RDMWaveformMarker)
  /// Tells when the user update `RDMWaveformMarker.data`.
  func markerDidUpdateData(_ marker: RDMWaveformMarker)
}
