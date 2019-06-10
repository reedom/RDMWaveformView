//
//  Marker.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/20.
//

/// `Marker` represents a marker, which works as like a bookmark.
/// With a mark, the user can jump to a specific time position to start playback, or
/// can have section-loop-playback feature.
public class Marker: NSObject {
  /// A unique ID.
  public let uuid: String

  /// A time position in a track at which this marker places.
  public var time: TimeInterval {
    didSet {
      guard time != oldValue else { return }
      updatedAt = Date()
      delegate?.markerDidUpdateTime(self)
    }
  }

  public var skip = false

  private var _data: Data?

  /// `data` can hold any kind of data that to be bind with a marker.
  public var data: Data? {
    didSet {
      guard data != nil || oldValue != nil else { return }
      var modified = false
      if let data = data, let oldValue = oldValue {
        modified = (data.count != oldValue.count) || !data.elementsEqual(oldValue)
      } else {
        modified = true
      }
      if modified {
        updatedAt = Date()
        delegate?.markerDidUpdateData(self)
      }
    }
  }

  /// Updated time.
  public private(set) var updatedAt: Date

  /// The delegate of this object.
  weak var delegate: MarkerDelegate?

  /// Initialize the instance.
  public init(uuid: String, time: TimeInterval, data: Data? = nil, skip: Bool = false, updated: Date? = nil) {
    self.uuid = uuid
    self.time = time
    self.skip = skip
    self.data = data
    self.updatedAt = updated ?? Date()
  }

  /// Initialize the instance.
  public convenience init(time: TimeInterval, data: Data? = nil, skip: Bool = false, updated: Date? = nil) {
    self.init(uuid: UUID().uuidString, time: time, data: data, skip: skip, updated: updated)
  }

  /// Initialize the instance.
  public convenience init(time: TimeInterval, data: Data? = nil, updated: Date? = nil) {
    self.init(uuid: UUID().uuidString, time: time, data: data, skip: false, updated: updated)
  }

  /// Initialize the instance.
  public convenience init(time: TimeInterval, updated: Date? = nil) {
    self.init(uuid: UUID().uuidString, time: time, data: nil, skip: false, updated: updated)
  }

  static func ==(lhs: Marker, rhs: Marker) -> Bool {
    return lhs.uuid == rhs.uuid
  }

  static func !=(lhs: Marker, rhs: Marker) -> Bool {
    return lhs.uuid != rhs.uuid
  }

  public func copyPropertiesFrom(_ other: Marker) {
    time = other.time
    data = other.data
    skip = other.skip
    updatedAt = other.updatedAt
  }
}
