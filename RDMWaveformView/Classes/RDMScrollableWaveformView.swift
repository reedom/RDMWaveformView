//
//  RDMScrollableWaveformView.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 4/14/19.
//  Copyright © 2019 reedom. All rights reserved.
//

import UIKit
import MediaPlayer
import AVFoundation
import SparseRanges

/// A view for rendering audio waveforms
open class RDMScrollableWaveformView: UIView {
  // MARK: - Types
  public enum WaveformAlignment {
    case none
    case center
  }

  public enum ScrollDirection {
    case none
    case forward
    case backward
  }

  public struct WaveformRenderOptions {
    let widthPerSecond: Int
    let linesPerSecond: Int
    let lineWidth: CGFloat
  }

  // MARK: - Properties

  /// A delegate to accept progress reporting
  open weak var delegate: RDMScrollableWaveformViewDelegate?

  open var preloadShorterThan: TimeInterval {
    get { return contentView.preloadShorterThan }
    set { contentView.preloadShorterThan = newValue }
  }

  /// The audio URL to render
  open var audioURL: URL? {
    didSet {
      guard let audioURL = audioURL else {
        NSLog("RDMWaveformView received nil audioURL")
        audioContext = nil
        return
      }

      // Start downloading
      _loadingInProgress = true
      delegate?.scrollableWaveformView?(self, willLoad: audioURL)

      NSLog("loading audio track from \(audioURL)")
      RDMAudioContext.load(fromAudioURL: audioURL) { audioContext in
        DispatchQueue.main.async {
          guard self.audioURL == audioContext?.audioURL else { return }

          if audioContext == nil {
            NSLog("RDMWaveformView failed to load URL: \(audioURL)")
          } else {
            NSLog("loaded audio track from \(audioURL)")
            NSLog("audio track duration: \(audioContext!.asset.duration.seconds)secs")
          }

          self.audioContext = audioContext // This will reset the view and kick off a layout
          self._loadingInProgress = false
          self.delegate?.scrollableWaveformView?(self, didLoad: audioURL)
        }
      }
    }
  }

  // MARK: - View properties

  public var waveformBackgroundColor = UIColor(red: 26/255, green: 25/255, blue: 31/255, alpha: 1) {
    didSet {
      contentView.backgroundColor = waveformBackgroundColor
    }
  }


  public var marginBackgroundColor = UIColor(red: 18/255, green: 18/255, blue: 20/255, alpha: 1) {
    didSet {
      scrollView.backgroundColor = marginBackgroundColor
    }
  }

  public var waveformContentAlignment = WaveformAlignment.center {
    didSet {
      setNeedsLayout()
    }
  }

  public var waveformRenderOptions = WaveformRenderOptions(widthPerSecond: 100, linesPerSecond: 25, lineWidth: 1) {
    didSet {
      contentView.resolution = resolution
    }
  }

  private var resolution: RDMWaveformResolution {
    return .perSecond(width: waveformRenderOptions.widthPerSecond,
                      lines: waveformRenderOptions.linesPerSecond,
                      lineWidth: waveformRenderOptions.lineWidth)
  }

  /// `scrollView` contains `contentView` and `guageView`.
  open lazy var scrollView: UIScrollView = {
    let scrollView = UIScrollView(frame: bounds)
    scrollView.backgroundColor = marginBackgroundColor
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    addSubview(scrollView)
    scrollView.delegate = self
    return scrollView
  }()

  /// `contentView` renders a waveform.
  public lazy var contentView: RDMWaveformContentView = {
    let contentView = RDMWaveformContentView()
    contentView.resolution = resolution
    contentView.backgroundColor = waveformBackgroundColor
    contentView.contentMode = .redraw
    scrollView.addSubview(contentView)
    return contentView
  }()

  /// `guageView` renders a time guage. Used optionally.
  public lazy var guageView: RDMWaveformTimeGuageView = {
    let guageView = RDMWaveformTimeGuageView()
    guageView.backgroundColor = marginBackgroundColor
    scrollView.addSubview(guageView)
    return guageView
  }()

  public lazy var centerGuide: RDMCenterGuide = {
    let view = RDMCenterGuide()
    addSubview(view)
    view.isUserInteractionEnabled = false
    view.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
    return view
  }()

  // MARK: - State properties

  private var _inTimeSeekMode = false
  public var inTimeSeekMode: Bool {
    return _inTimeSeekMode
  }

  /// Whether loading is happening asynchronously
  private var _loadingInProgress = false
  open var loadingInProgress: Bool {
    return _loadingInProgress
  }

  /// The total number of audio samples in the current track.
  public var totalSamples: Int {
    return audioContext?.totalSamples ?? 0
  }

  /// The total duration of the current track.
  public var duration: CMTime {
    return audioContext?.asset.duration ?? CMTime.zero
  }

  /// The current time that the waveform points at.
  public var time: TimeInterval {
    get {
      guard 0 < totalSamples, 0 < contentView.frame.width else { return 0 }
      let progress = scrollView.contentOffset.x / contentView.frame.width
      return duration.seconds * Double(progress)
    }
    set {
      guard 0 < totalSamples else { return }
      let seconds = max(0, min(duration.seconds, newValue))
      let progress = seconds / duration.seconds
      let x = contentView.frame.width * CGFloat(progress)
      scrollView.contentOffset = CGPoint(x: x, y: 0)
    }
  }

  /// The current position in the sampling data that the waveform points at.
  public var position: Int {
    get {
      guard let audioContext = audioContext else { return 0 }
      return Int(time * TimeInterval(audioContext.sampleRate))
    }
    set {
      guard 0 < totalSamples else { return }
      let progress = Double(newValue) / Double(totalSamples)
      time = duration.seconds * progress
    }
  }

  // MARK: - Marker property

  /// The samples to be highlighted in a different color
  open var markers = [RDMWaveformMarker]() {
    didSet {
      guard audioContext != nil else { return }
      setNeedsLayout()
    }
  }

  // MARK: - helper properties

  private var contentMargin: CGFloat {
    switch waveformContentAlignment{
    case .center:
      return scrollView.frame.width / 2
    case .none:
      return 0
    }
  }

  public var guageHeight: CGFloat = 22 {
    didSet {
      setNeedsLayout()
    }
  }

  // MARK: - Private vars

  /// Current audio context to be used for rendering
  private var audioContext: RDMAudioContext? {
    didSet {
      contentView.audioContext = audioContext
      reset()
      setNeedsLayout()
    }
  }

  private var lastScrollContentOffset: CGFloat = 0

  // MARK: - view lifecycle

  deinit {
    contentView.cancel()
  }
}

extension RDMScrollableWaveformView {
  override open func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    if newWindow == nil {
      contentView.cancel()
    }
  }

  override open func layoutSubviews() {
    super.layoutSubviews()

    centerGuide.isHidden = waveformContentAlignment != .center
    if centerGuide.isHidden {
      scrollView.frame = bounds
    } else {
      scrollView.frame = bounds.insetBy(dx: 0, dy: centerGuide.markerDiameter)
      centerGuide.frame = bounds
      bringSubviewToFront(centerGuide)
    }

    guard 0 < totalSamples else {
      // TODO show empty view
      return
    }

    let waveformWidth = contentView.contentWidth
    scrollView.contentSize = CGSize(width: ceil(waveformWidth + contentMargin * 2),
                                    height: scrollView.frame.height)
    contentView.marginLeft = contentMargin
    contentView.visibleWidth = scrollView.frame.width
    if guageView.isHidden {
      contentView.frame = CGRect(x: ceil(contentMargin),
                                 y: 0,
                                 width: waveformWidth,
                                 height: scrollView.contentSize.height)
    } else {
      contentView.frame = CGRect(x: ceil(contentMargin),
                                 y: 0,
                                 width: waveformWidth,
                                 height: scrollView.contentSize.height - guageHeight)
      guageView.marginLeft = contentMargin
      guageView.visibleWidth = scrollView.frame.width
      guageView.frame = CGRect(x: guageView.labelPaddingLeft,
                               y: contentView.frame.maxY,
                               width: scrollView.contentSize.width + scrollView.frame.width,
                               height: guageHeight)
    }

    guageView.contentOffset = scrollView.contentOffset.x
    contentView.setNeedsDisplay()
  }
}

// MARK: - Waveform content management

extension RDMScrollableWaveformView {
  // Downsample entire track in advance so that it won't show
  // delay in further rendering process.
  public func downsampleAll() {
    contentView.downsampler?.downsampleAll()
  }

  public func reset() {
    contentView.reset()
    guageView.reset()
    setNeedsLayout()
  }
}

// MARK: - UIScrollViewDelegate
extension RDMScrollableWaveformView: UIScrollViewDelegate {
  public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    if !_inTimeSeekMode {
      _inTimeSeekMode = true
      delegate?.scrollableWaveformView?(self, willEnterSeekMode: time)
    }
  }

  public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    // `scrollView.isDecelerating` may have been turned on right after this event.
    // To detect it, we intentionally get one-frame-delay by calling `DispatchQueue.main.async`.
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if !scrollView.isDecelerating {
        self._inTimeSeekMode = false
        self.delegate?.scrollableWaveformView?(self, didLeaveSeekMode: self.time)
      }
    }
  }

  // any offset changes
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let contentOffset = max(0, min(scrollView.contentSize.width, scrollView.contentOffset.x))
    let scrollDirection = self.scrollDirection(newContentOffset: contentOffset)
    lastScrollContentOffset = contentOffset

    guageView.contentOffset = scrollView.contentOffset.x
    contentView.update(contentOffset: contentOffset,
                       direction: scrollDirection)
    delegate?.scrollableWaveformView?(self, didSeek: time)
  }

  public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    _inTimeSeekMode = false
    self.delegate?.scrollableWaveformView?(self, didLeaveSeekMode: time)
  }

  private func scrollDirection(newContentOffset: CGFloat) -> ScrollDirection {
    if lastScrollContentOffset < newContentOffset {
      return .forward
    } else if scrollView.contentOffset.x < lastScrollContentOffset {
      return .backward
    } else {
      return .none
    }
  }
}

/// To receive progress updates from RDMWaveformView
@objc public protocol RDMScrollableWaveformViewDelegate: NSObjectProtocol {
  /// An audio file will be loaded
  @objc optional func scrollableWaveformView(_ scrollableWaveformView: RDMScrollableWaveformView, willLoad url: URL)

  /// An audio file was loaded
  @objc optional func scrollableWaveformView(_ scrollableWaveformView: RDMScrollableWaveformView, didLoad url: URL)

  /// The pan gesture will start
  @objc optional func scrollableWaveformView(_ scrollableWaveformView: RDMScrollableWaveformView, willEnterSeekMode time: TimeInterval)

  /// The pan gesture did end
  @objc optional func scrollableWaveformView(_ scrollableWaveformView: RDMScrollableWaveformView, didLeaveSeekMode time: TimeInterval)

  /// time was changed
  @objc optional func scrollableWaveformView(_ scrollableWaveformView: RDMScrollableWaveformView, didSeek time: TimeInterval)
}
