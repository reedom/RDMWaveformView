//
//  RDMWaveformResolution.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/06.
//

import UIKit

/// Resolution in Waveform rendering.
public enum RDMWaveformResolution {
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

extension RDMWaveformResolution {
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
