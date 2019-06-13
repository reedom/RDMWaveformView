//
//  SurroundMarker.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/06/12.
//

import Foundation

public class SurroundMarker: NSObject {
  public let upperBound: Marker?
  public let lowerBound: Marker?

  public init(upperBound: Marker?, lowerBound: Marker?) {
    self.upperBound = upperBound
    self.lowerBound = lowerBound
  }

  static let empty = SurroundMarker(upperBound: nil, lowerBound: nil)
}

extension SurroundMarker {
  public var isEmpty: Bool {
    return upperBound == nil && lowerBound == nil
  }

  public func contains(time: TimeInterval) -> Bool {
    if let lowerBound = lowerBound?.time {
      if lowerBound.isEqual(to: time) {
        return true
      } else if time < lowerBound {
        return false
      }
    }
    if let upperBound = upperBound?.time {
      if upperBound.isEqual(to: time) || upperBound < time {
        return false
      }
    }
    return true
  }

  public func relates(with marker: Marker) -> Bool {
    if let upperBound = upperBound, marker == upperBound {
      return true
    }
    if let lowerBound = lowerBound, marker == lowerBound {
      return true
    }
    return false
  }
}
