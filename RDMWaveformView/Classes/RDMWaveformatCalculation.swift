//
//  RDMWaveformCalclation.swift
//  music player
//
//  Created by HANAI Tohru on 4/12/19.
//  Copyright © 2019 reedom. All rights reserved.
//

import UIKit
import AVFoundation

public protocol RDMWaveformCalculator {
  /// Current audio context to be used for rendering
  var audioContext: RDMAudioContext { get }

  /// Time at the beginning of the target waveform.
  var time: CMTime { get }
  /// Duration of the target waveform in seconds.
  var duration: Double { get }
  /// Sampling data range of the target waveform.
  var sampleRange: CountableRange<Int> { get }

  /// Count of downscaled sampling data that waveform renderer will use.
  var targetSamples: Int { get }
  /// Rendering target rectangle in a view to draw the target waveform.
  var targetRect: CGRect { get }
  /// Width of a waveform decibel line in pixel.
  var lineWidth: Int { get }
  /// Space between waveform decibel lines in pixel.
  var lineStride: Int { get }

  /// Check whether the data contents is valid or not.
  var isValid: Bool { get }
  /// Determine whether a waveform should exist before this.
  var hasPrevPage: Bool { get }
  /// Determine whether a waveform should exist after this.
  var hasNextPage: Bool { get }
}

/// Format options for RDMWaveformRenderOperation
public class RDMWaveformEntireTrackCalculator: RDMWaveformCalculator {
  /// Current audio context to be used for rendering
  public let audioContext: RDMAudioContext

  public let targetRect: CGRect
  public let lineWidth: Int
  public let lineStride: Int

  public let hasNextPage = false
  public let hasPrevPage = false

  public init(audioContext: RDMAudioContext,
              targetRect: CGRect,
              lineWidth: Int,
              lineStride: Int) {
    self.audioContext = audioContext
    self.targetRect = targetRect
    self.lineWidth = lineWidth
    self.lineStride = lineStride
  }

  public var duration: Double {
    get { return audioContext.asset.duration.seconds }
  }

  public let time = CMTime.zero

  public var sampleRate: Int {
    get { return audioContext.sampleRate }
  }

  public var targetSamples:  Int {
    return Int(ceil(targetRect.width / CGFloat(lineWidth + lineStride)))
  }

  public var sampleRange: CountableRange<Int> {
    return 0..<audioContext.totalSamples
  }

  public lazy var isValid: Bool = {
    return !sampleRange.isEmpty && 0 < targetRect.width && 0 < targetRect.height
  }()
}

public class RDMWaveformPerSecondCalculator: RDMWaveformCalculator {
  /// Current audio context to be used for rendering
  public let audioContext: RDMAudioContext

  public let sampleRange: CountableRange<Int>
  public let targetRect: CGRect
  public let widthPerSecond: Int
  public let linesPerSecond: Int
  public let lineWidth: Int

  public init(audioContext: RDMAudioContext,
              sampleRange: CountableRange<Int>,
              targetRect: CGRect,
              widthPerSecond: Int,
              linesPerSecond: Int,
              lineWidth: Int) {
    self.audioContext = audioContext
    self.sampleRange = sampleRange
    self.targetRect = targetRect
    self.widthPerSecond = widthPerSecond
    self.linesPerSecond = linesPerSecond
    self.lineWidth = lineWidth
    print("sampleRange: \(sampleRange)")
  }

  public lazy var duration: Double = {
    let duration = CMTime(value: Int64(sampleRange.count), timescale: audioContext.asset.duration.timescale)
    return duration.seconds
  }()

  public var time: CMTime {
    get { return CMTime(value: Int64(sampleRange.lowerBound), timescale: audioContext.asset.duration.timescale) }
  }

  public lazy var viewSize: CGSize = {
    let width = ceil(CGFloat(widthPerSecond) * CGFloat(duration))
    return CGSize(width: width, height: targetRect.height)
  }()

  public lazy var lineStride: Int = {
    return widthPerSecond / linesPerSecond - lineWidth
  }()

  public lazy var targetSamples: Int = {
    let t = Double(linesPerSecond) * duration
    print("duration: \(duration), linesPerSecond: \(linesPerSecond), targetSamples: \(t)")
    return Int(t)
  }()

  public lazy var hasPrevPage: Bool = {
    return 0 < sampleRange.lowerBound
  }()

  public lazy var hasNextPage: Bool = {
    return sampleRange.upperBound < audioContext.totalSamples
  }()

  public var isValid: Bool {
    get { return !sampleRange.isEmpty && 0 < targetRect.width && 0 < targetRect.height }
  }
}
