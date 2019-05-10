//
//  RDMScrollableWaveformContentView.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 4/18/19.
//

import UIKit
import MediaPlayer
import AVFoundation
import SparseRanges

/// A view specialized for UIScrollView to display an audio's waveform.
open class RDMScrollableWaveformContentView: UIView {

  // MARK: - Properties for downsampling

  /// Downsampler.
  var downsampler: RDMAudioDownsampler?
  /// Calcurator around waveform and its view.
  var calculator: RDMWaveformCalc?
  /// Parameters for the renderer.
  var rendererParams: RDMWaveformRendererParams?

  // MARK: - Drawing properties

  public var visibleWidth: CGFloat = 0
  public var marginLeft: CGFloat = 0

  private var contentOffset: CGFloat = 0

  /// A collection of content views in use.
  private var activeContents = [RDMWaveformContentView]()
  /// A object pool of deactive content views.
  private var deactiveContents = [RDMWaveformContentView]()

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
  }
}

extension RDMScrollableWaveformContentView {
  public typealias ScrollDirection = RDMScrollableWaveformView.ScrollDirection

  public func update(contentOffset: CGFloat = 0, direction: ScrollDirection = .none) {
    self.contentOffset = contentOffset
    guard
      downsampler != nil,
      let calculator = calculator
      else { return }

    let timeRange = currentTimeRangeInView()
    timeRange.forEach { (seconds) in
      guard !activeContents.contains(where: { $0.timeRange.lowerBound == seconds }) else { return }
      let contentView = !deactiveContents.isEmpty ? deactiveContents.removeFirst() : createContentView()
      let timeRange = seconds ..< seconds+1
      contentView.isHidden = false
      contentView.frame = calculator
        .rectFrom(timeRange: timeRange, height: frame.height)
        .insetBy(dx: -0.5, dy: 0)
      print("for timeRange: \(timeRange), frame = \(contentView.frame)")
      contentView.startRenderingProcedure(timeRange: timeRange)
      activeContents.append(contentView)
    }

    activeContents.removeAll(where: { contentView in
      if contentView.timeRange.upperBound <= timeRange.lowerBound ||
        timeRange.upperBound <= contentView.timeRange.lowerBound {
        contentView.isHidden = true
        deactiveContents.append(contentView)
        return true
      }
      return false
    })
  }
}

// MARK: - unit converters

extension RDMScrollableWaveformContentView {
  private func createContentView() -> RDMWaveformContentView {
    print("createContentView")
    let contentView = RDMWaveformContentView()
    addSubview(contentView)
    contentView.calculator = calculator
    contentView.downsampler = downsampler
    contentView.cancelRendering()
    contentView.rendererParams = rendererParams
    return contentView
  }

  private func currentTimeRangeInView() -> TimeRange {
    guard
      0 < visibleWidth,
      let calculator = calculator
      else { return 0..<0 }
    let from = contentOffset - marginLeft
    let to = contentOffset + visibleWidth - marginLeft
    let r = calculator.timeRangeInView(from, to)
    return Int(r.lowerBound) ..< Int(ceil(r.upperBound))
  }

  private func visibleRect() -> CGRect {
    return CGRect(x: contentOffset, y: 0, width: visibleWidth, height: frame.height)
  }
}

