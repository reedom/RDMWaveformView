//
//  RDMWaveformMarker.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/04/22.
//

import UIKit

public struct RDMWaveformMarker {
  public let uuid: String
  public let position: Int
  public let data: Data?

  public init(uuid: String, position: Int, data: Data? = nil) {
    self.uuid = uuid
    self.position = position
    self.data = data
  }

  public init(position: Int, data: Data? = nil) {
    self.uuid = UUID().uuidString
    self.position = position
    self.data = data
  }
}

extension RDMWaveformMarker {
  public func copy(withPosition position: Int) -> RDMWaveformMarker {
    return RDMWaveformMarker(uuid: uuid, position: position, data: data)
  }

  public func copy(withData data: Data?) -> RDMWaveformMarker {
    return RDMWaveformMarker(uuid: uuid, position: position, data: data)
  }
}
