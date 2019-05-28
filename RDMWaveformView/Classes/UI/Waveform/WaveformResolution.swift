//
//  WaveformResolution.swift
//  WaveformView
//
//  Created by HANAI Tohru on 2019/05/06.
//

import UIKit

/// Resolution in Waveform rendering.
public enum WaveformResolution {
  /// The entire wavelength fits the view's width.
  ///
  /// - Parameter stride: A space between lines, in pixels.
  /// - Parameter lineWidth: Width of each line.
  case byViewWidth(stride: CGFloat, lineWidth: CGFloat)
  /// It renders each second with the specified width.
  ///
  /// - Parameter width: width per second in pixels.
  /// - Parameter lines: count of lines in a second.
  /// - Parameter lineWidth: Width of each line.
  case perSecond(width: Int, lines: Int, lineWidth: CGFloat)
}

extension WaveformResolution {
  public var lineWidth: CGFloat {
    switch self {
    case .byViewWidth(_, let lineWidth):
      return lineWidth
    case .perSecond(_, _, let lineWidth):
      return lineWidth
    }
  }

  public var lineStride: CGFloat {
    switch self {
    case .byViewWidth(let stride, _):
      return stride
    case .perSecond(let width, let lines, _):
      return CGFloat(width) / CGFloat(lines)
    }
  }
}

extension WaveformResolution {
  static func ==(lhs: WaveformResolution, rhs: WaveformResolution) -> Bool {
    switch lhs {
    case .byViewWidth(let stride1, let lineWidth1):
      switch rhs {
      case .byViewWidth(let stride2, let lineWidth2):
        return stride1 == stride2 && lineWidth1 == lineWidth2
      case .perSecond(_, _, _):
        return false
      }
    case .perSecond(let width1, let lines1, let lineWidth1):
      switch rhs {
      case .byViewWidth(_, _):
        return false
      case .perSecond(let width2, let lines2, let lineWidth2):
        return width1 == width2 && lines1 == lines2 && lineWidth1 == lineWidth2
      }
    }
  }

  static func !=(lhs: WaveformResolution, rhs: WaveformResolution) -> Bool {
    return !(lhs == rhs)
  }
}
