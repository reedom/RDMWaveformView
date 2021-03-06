//
//  DownsampleCacher.swift
//  FBSnapshotTestCase
//
//  Created by HANAI Tohru on 2019/05/29.
//

import Foundation
import NSString_Hash
import Gzip

public protocol DownsampleCacher {
  func load(url: URL, callback: @escaping (_ downsamples: [CGFloat]?) -> Void)
  func save(url: URL, downsamples: [CGFloat], callback: @escaping (_ error: Error?) -> Void)
}

open class DownsampleFileCacher: DownsampleCacher {
  public lazy var directory: URL = {
    var dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    dir = dir.appendingPathComponent("downsamples")
    if !FileManager.default.fileExists(atPath: dir.path) {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false, attributes: nil)
    }
    return dir
  }()

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
    return directory.appendingPathComponent((url.absoluteString as NSString).sha256())
  }
}

open class DownsampleGZipFileCacher: DownsampleCacher {
  public lazy var directory: URL = {
    var dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    dir = dir.appendingPathComponent("downsamples")
    if !FileManager.default.fileExists(atPath: dir.path) {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false, attributes: nil)
    }
    return dir
  }()

  public init() {
  }

  public func load(url: URL, callback: @escaping (_ downsamples: [CGFloat]?) -> Void) {
    let filePath = self.filePath(for: url)
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: filePath.path) else {
      callback(nil)
      return
    }

    do {
      let gzipped = try Data(contentsOf: filePath)
      let downsamples = NSKeyedUnarchiver.unarchiveObject(with: try gzipped.gunzipped()) as? [CGFloat]
      callback(downsamples)
    } catch {
      callback(nil)
    }
  }

  public func save(url: URL, downsamples: [CGFloat], callback: @escaping (_ error: Error?) -> Void) {
    let filePath = self.filePath(for: url)
    let data = NSKeyedArchiver.archivedData(withRootObject: downsamples)
    do {
      let gzipped = try data.gzipped()
      try gzipped.write(to: filePath)
      callback(nil)
    } catch {
      callback(error)
    }
  }

  open func filePath(for url: URL) -> URL {
    return directory.appendingPathComponent((url.absoluteString as NSString).sha256() + ".gz")
  }
}
