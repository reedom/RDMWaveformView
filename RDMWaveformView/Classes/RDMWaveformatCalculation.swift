//
//  RDMWaveformCalclation.swift
//  music player
//
//  Created by HANAI Tohru on 4/12/19.
//  Copyright © 2019 reedom. All rights reserved.
//

import UIKit
import AVFoundation

struct RDMWaveformAttributes {
  /// The color of the waveform
  let wavesColor: UIColor

  /// The "zero" level (in dB)
  let noiseFloor: CGFloat
}

protocol RDMWaveformCalculator {
  /// Current audio context to be used for rendering
  var audioContext: RDMAudioContext { get }

  var duration: Double { get }

  var time: CMTime { get }

  var targetSamples: Int { get }

  var sampleRange: CountableRange<Int>  { get }

  var viewSize: CGSize { get }
  var lineWidth: Int { get }
  var lineStride: Int { get }

  var isValid: Bool { get }
  var hasPrevPage: Bool { get }
  var hasNextPage: Bool { get }
}

/// Format options for RDMWaveformRenderOperation
class RDMWaveformEntireTrackCalculator: RDMWaveformCalculator {
  /// Current audio context to be used for rendering
  let audioContext: RDMAudioContext

  let viewSize: CGSize
  let lineWidth: Int
  let lineStride: Int

  let hasNextPage = false
  let hasPrevPage = false

  init(audioContext: RDMAudioContext,
       viewSize: CGSize,
       lineWidth: Int,
       lineStride: Int) {
    self.audioContext = audioContext
    self.viewSize = viewSize
    self.lineWidth = lineWidth
    self.lineStride = lineStride
  }

  var duration: Double {
    get { return audioContext.asset.duration.seconds }
  }

  let time = CMTime.zero

  var sampleRate: Int {
    get { return audioContext.sampleRate }
  }

  var targetSamples:  Int {
    return Int(ceil(viewSize.width / CGFloat(lineWidth + lineStride)))
  }

  var sampleRange: CountableRange<Int> {
    return 0..<audioContext.totalSamples
  }

  lazy var isValid: Bool = {
    return !sampleRange.isEmpty && 0 < viewSize.width && 0 < viewSize.height
  }()
}

class RDMWaveformPerSecondCalculator: RDMWaveformCalculator {
  /// Current audio context to be used for rendering
  let audioContext: RDMAudioContext

  let samplePosition: Int

  let frameSize: CGSize

  let widthPerSecond: Int
  let linesPerSecond: Int
  let lineWidth: Int

  private let basicDuration: Double

  init(audioContext: RDMAudioContext,
       samplePosition: Int,
       frameSize: CGSize,
       widthPerSecond: Int,
       linesPerSecond: Int,
       lineWidth: Int) {
    self.audioContext = audioContext
    self.samplePosition = samplePosition
    self.frameSize = frameSize
    self.hasPrevPage = 0 < samplePosition
    self.widthPerSecond = widthPerSecond
    self.linesPerSecond = linesPerSecond
    self.lineWidth = lineWidth

    self.basicDuration = Double(ceil(frameSize.width * 2 / CGFloat(widthPerSecond)))
  }

  lazy var duration: Double = {
    if hasNextPage {
      return basicDuration
    } else {
      let remainSamples = audioContext.totalSamples - samplePosition
      let duration = CMTime(value: Int64(remainSamples), timescale: audioContext.asset.duration.timescale)
      return duration.seconds
    }
  }()

  var time: CMTime {
    get { return CMTime(value: Int64(samplePosition), timescale: audioContext.asset.duration.timescale) }
  }

  lazy var viewSize: CGSize = {
    let width = ceil(CGFloat(widthPerSecond) * CGFloat(duration))
    return CGSize(width: width, height: frameSize.height)
  }()

  lazy var lineStride: Int = {
    return widthPerSecond / linesPerSecond - lineWidth
  }()

  lazy var targetSamples: Int = {
    let t = Double(linesPerSecond) * duration
    print("duration: \(duration), linesPerSecond: \(linesPerSecond), targetSamples: \(t)")
    return Int(t)
  }()

  lazy var sampleRange: CountableRange<Int> = {
    let end = samplePosition + Int(Double(audioContext.sampleRate) * basicDuration)
    return samplePosition ..< min(end, audioContext.totalSamples)
  }()

  let hasPrevPage: Bool

  lazy var hasNextPage: Bool = {
    return sampleRange.upperBound < audioContext.totalSamples
  }()

  var isValid: Bool {
    get { return !sampleRange.isEmpty && 0 < frameSize.width && 0 < frameSize.height }
  }
}
