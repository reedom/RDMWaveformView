//
//  RDMAudioDownsampleCalc.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 2019/05/10.
//

struct RDMAudioDownsampleCalc {
  /// Holds audio information used for building waveforms.
  let audioContext: RDMAudioContext
  /// Downsample rate.
  /// `RDMAudioLoadOperation` uses the specified number of samples to generate
  /// a downsampled value.
  let downsampleRate: Int

  init(_ audioContext: RDMAudioContext, _ downsampleRate: Int) {
    self.audioContext = audioContext
    self.downsampleRate = downsampleRate
  }

  /// Caluclate downsample data indice for the specified time range.
  func downsampleRangeFrom(timeRange: TimeRange) -> DownsampleRange {
    let lowerBound = timeRange.lowerBound * audioContext.sampleRate / downsampleRate
    let upperBound = timeRange.upperBound * audioContext.sampleRate / downsampleRate
    return lowerBound ..< upperBound
  }

  /// Caluclate time range in seconds for the specified downsample indice.
  func timeRangeFrom(downsampleRange: DownsampleRange) -> TimeRange {
    let lowerBound = downsampleRange.lowerBound * downsampleRate / audioContext.sampleRate
    let upperBound = Int(ceil(Float(downsampleRange.upperBound * downsampleRate) / Float(audioContext.sampleRate)))
    return lowerBound ..< upperBound
  }
}
