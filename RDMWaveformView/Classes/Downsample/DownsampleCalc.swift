//
//  DownsampleCalc.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/20.
//

import Foundation

/// Caluclate downsample data indice for the specified time range.
func downsampleRangeFrom(_ audioContext: AudioContext, _ downsampleRate: Int, timeRange: TimeRange) -> DownsampleRange {
  let lowerBound = timeRange.lowerBound * audioContext.sampleRate / downsampleRate
  let upperBound = timeRange.upperBound * audioContext.sampleRate / downsampleRate
  return lowerBound ..< upperBound
}

/// Caluclate time range in seconds for the specified downsample indice.
func timeRangeFrom(_ audioContext: AudioContext, _ downsampleRate: Int, downsampleRange: DownsampleRange) -> TimeRange {
  let lowerBound = downsampleRange.lowerBound * downsampleRate / audioContext.sampleRate
  let upperBound = Int(ceil(Float(downsampleRange.upperBound * downsampleRate) / Float(audioContext.sampleRate)))
  return lowerBound ..< upperBound
}
