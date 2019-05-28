//
//  AudioError.swift
//  FBSnapshotTestCase
//
//  Created by HANAI Tohru on 2019/04/30.
//

public class AudioError: Error {
  public let message: String

  public init(_ message: String) {
    self.message = message
  }
}
