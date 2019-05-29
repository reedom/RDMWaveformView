//
//  DownsampleCacher.swift
//  FBSnapshotTestCase
//
//  Created by HANAI Tohru on 2019/05/29.
//

import Foundation

public protocol DownsampleCacher {
  func load(url: URL, callback: @escaping (_ downsamples: [CGFloat]?) -> Void)
  func save(url: URL, downsamples: [CGFloat], callback: @escaping (_ error: Error?) -> Void)
}

open class DownsampleFileCacher: DownsampleCacher {
  public var directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

  public init() {
  }

  public func load(url: URL, callback: @escaping (_ downsamples: [CGFloat]?) -> Void) {
    let filePath = self.filePath(for: url)
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: filePath.path) else {
      callback(nil)
      return
    }

    let downsamples = NSArray(contentsOf: filePath) as? [CGFloat]
    callback(downsamples)
  }

  public func save(url: URL, downsamples: [CGFloat], callback: @escaping (_ error: Error?) -> Void) {
    let filePath = self.filePath(for: url)
    (downsamples as NSArray).write(to: filePath, atomically: true)
  }

  open func filePath(for url: URL) -> URL {
    return directory.appendingPathComponent(url.absoluteString.sha256())
  }
}
