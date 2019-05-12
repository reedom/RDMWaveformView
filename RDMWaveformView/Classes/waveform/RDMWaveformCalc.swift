//
//  RDMWaveformCalc.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/06.
//

public struct RDMWaveformCalc {
  /// The total duration of the audio track.
  public let duration: TimeInterval
  /// Sampling rate of the audio track.
  public let sampleRate: Int

  /// Resolution in Waveform rendering.
  public let resolution: RDMWaveformResolution
  // public let totalDownsample: Int
  /// The entire width of the waveform view.
  public let totalWidth: CGFloat
  /// Total number of sampling data per channel of the audio track.
  public var totalSamples: Int {
    return Int(duration * TimeInterval(sampleRate))
  }

  public init(duration: TimeInterval,
              sampleRate: Int,
              resolution: RDMWaveformResolution,
              totalWidth: CGFloat? = nil) {
    self.duration = duration
    self.sampleRate = sampleRate
    self.resolution = resolution
    if let totalWidth = totalWidth {
      self.totalWidth = totalWidth
    } else {
      switch resolution {
      case .byViewWidth(_, _):
        fatalError("cannot omit totalWidth")
      case .perSecond(let widthPerSecond, _, _):
        self.totalWidth = CGFloat(duration) * CGFloat(widthPerSecond)
      }
    }
  }
}

extension RDMWaveformCalc {
  /// Calculate downsample rate.
  public var downsampleRate: Int {
    switch resolution {
    case .byViewWidth(let stride, _):
      let lines = totalWidth / CGFloat(stride)
      guard 0 < lines else { return 1 }
      return max(1, Int(CGFloat(totalSamples) / lines))
    case .perSecond(_, let linesPerSecond, _):
      let totalLines = duration * Double(linesPerSecond)
      return max(1, Int(ceil(Double(totalSamples) / totalLines)))
    }
  }

  /// Calculate rendering rectangle for the `timeRange`.
  public func rectFrom(downsampleRange: DownsampleRange, height: CGFloat) -> CGRect {
    let x1 = xFromDownsampleIndex(downsampleRange.lowerBound)
    let x2 = xFromDownsampleIndex(downsampleRange.upperBound)
    return CGRect(x: x1, y: 0, width: x2 - x1, height: height)
  }

  public func xFromDownsampleIndex(_ i: Int) -> CGFloat {
    switch resolution {
    case .byViewWidth(let stride, _):
      return max(0, min(totalWidth, CGFloat(i) * stride))
    case .perSecond(let widthPerSecond, let linesPerSecond, _):
      guard 0 < linesPerSecond else { return 0 }
      let stride = widthPerSecond / linesPerSecond
      let x = widthPerSecond * (i / linesPerSecond) + stride * (i % linesPerSecond)
      return max(0, min(totalWidth, CGFloat(x)))
    }
  }

  /// Calculate rendering rectangle for the `timeRange`.
  public func rectFrom(timeRange: TimeRange, height: CGFloat, limits: Bool = true) -> CGRect {
    let x1 = xFromSeconds(timeRange.lowerBound, limits: limits)
    let x2 = xFromSeconds(timeRange.upperBound, limits: limits)
    return CGRect(x: x1, y: 0, width: x2 - x1, height: height)
  }

  /// Calculate x axis position for the specified time.
  public func xFromSeconds(_ seconds: Int, limits: Bool = true) -> CGFloat {
    guard 0 < duration else { return 0 }

    let progress = Double(seconds) / duration
    if limits {
      return max(0, min(totalWidth, round(totalWidth * CGFloat(progress))))
    } else {
      return max(0, round(totalWidth * CGFloat(progress)))
    }
  }

  /// Calculate time range for the `from`-`to` positions in the view.
  ///
  /// - Parameter from: x-axis position that the range starts from.
  /// - Parameter to: x-axis position that the range ends at.
  public func timeRangeInView(_ from: CGFloat, _ to: CGFloat, limits: Bool = true) -> (lowerBound: Double, upperBound: Double) {
    switch resolution {
    case .byViewWidth(_, _):
      let lowerBound = Double(from) / Double(totalWidth) * duration
      let upperBound = Double(to) / Double(totalWidth) * duration
      if limits {
        return (max(0, min(duration, lowerBound)), max(0, min(duration, upperBound)))
      } else {
        return (max(0, lowerBound), max(0, upperBound))
      }
    case .perSecond(let widthPerSecond, _, _):
      let lowerBound = Double((from) / CGFloat(widthPerSecond))
      let upperBound = Double((to) / CGFloat(widthPerSecond))
      if limits {
        return (max(0, min(duration, lowerBound)), max(0, min(duration, upperBound)))
      } else {
        return (max(0, lowerBound), max(0, upperBound))
      }
    }
  }
}
