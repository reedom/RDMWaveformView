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
    let scrollView = RDMWaveformScrollView(frame: bounds)
    scrollView.backgroundColor = UIColor.transparent
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

  /// `contentBackgroundView` renders `marginBackgroundColor`
  public lazy var contentBackgroundView: UIView = {
    let view = UIView()
    view.backgroundColor = marginBackgroundColor
    scrollView.addSubview(view)
    return view
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
    view.backgroundColor = UIColor.transparent
    return view
  }()

  public lazy var markersContainer: RDMWaveformMarkersContainer = {
    let view = RDMWaveformMarkersContainer()
    addSubview(view)
    view.backgroundColor = UIColor.transparent
    return view
  }()

  public lazy var addMarkerButton: UIButton = {
    let button = UIButton(type: .custom)
    addSubview(button)
    button.setTitle("＋", for: .normal)
    button.contentHorizontalAlignment = .center
    button.contentVerticalAlignment = .bottom
    button.setTitleColor(markersContainer.markerColor, for: .normal)
    button.addTarget(self, action: #selector(addMarker), for: .touchUpInside)
    return button
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

  // MARK: - Subview on/off

  open var showMarker: Bool {
    get { return !markersContainer.isHidden }
    set {
      markersContainer.isHidden = !newValue
      setNeedsLayout()
    }
  }

  open var showGuage: Bool {
    get { return !guageView.isHidden }
    set {
      guageView.isHidden = !newValue
      setNeedsLayout()
    }
  }

  open var showCenterGuide: Bool {
    get { return !centerGuide.isHidden }
    set {
      centerGuide.isHidden = !newValue
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
      markersContainer.totalSamples = totalSamples
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

    guard 0 < totalSamples else {
      // TODO show empty view
      return
    }

    // Layout markersContainer and scrollView

    if showMarker {
      scrollView.frame = CGRect(x: 0,
                                y: markersContainer.markerTouchSize.height,
                                width: bounds.width,
                                height: bounds.height - markersContainer.markerTouchSize.height)
    } else {
      scrollView.frame = bounds
    }

    if showCenterGuide {
      if showGuage {
        // Cut top `centerGuide.markerDiameter` pixels off.
        // (No need to cut bottom since the bottom marker overlays in the guage area)
        scrollView.frame = scrollView.frame
          .insetBy(dx: 0, dy: centerGuide.markerDiameter)
          .offsetBy(dx: 0, dy: centerGuide.markerDiameter / 2)
      } else {
        // Shrink vertically
        scrollView.frame = scrollView.frame
          .insetBy(dx: 0, dy: centerGuide.markerDiameter)
      }
    }

    // Layout scrollView's subviews

    let waveformWidth = contentView.contentWidth
    scrollView.contentSize = CGSize(width: ceil(waveformWidth + contentMargin * 2),
                                    height: scrollView.frame.height)
    contentView.marginLeft = contentMargin
    contentView.visibleWidth = scrollView.frame.width
    if showGuage {
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
    } else {
      contentView.frame = CGRect(x: ceil(contentMargin),
                                 y: 0,
                                 width: waveformWidth,
                                 height: scrollView.contentSize.height)
    }
    contentBackgroundView.frame = CGRect(x: -scrollView.frame.width / 2,
                                         y: 0,
                                         width: scrollView.contentSize.width + scrollView.frame.width,
                                         height: contentView.frame.height)

    // Layout centerGuide

    if showCenterGuide {
      centerGuide.frame = CGRect(x: (bounds.width - centerGuide.markerDiameter) / 2,
                                 y: scrollView.frame.minY - centerGuide.markerDiameter,
                                 width: centerGuide.markerDiameter,
                                 height: contentView.frame.height + centerGuide.markerDiameter * 2)
    }

    // Layout makerContainer

    if showMarker {
      markersContainer.markerLineHeight = scrollView.frame.minY + contentView.frame.height
      markersContainer.frame = CGRect(x: contentView.frame.minX,
                                      y: 0,
                                      width: contentView.frame.width,
                                      height: markersContainer.markerTouchSize.height)
      addMarkerButton.frame = CGRect(x: frame.midX - markersContainer.markerTouchSize.width / 2,
                                     y: 0,
                                     width: markersContainer.markerTouchSize.width,
                                     height: markersContainer.markerTouchSize.height)
    }

    // Reorder subviews

    scrollView.sendSubviewToBack(contentBackgroundView)
    bringSubviewToFront(centerGuide)
    bringSubviewToFront(markersContainer)
    bringSubviewToFront(addMarkerButton)

    // Advice subviews to render

    guageView.contentOffset = scrollView.contentOffset.x
    contentView.setNeedsDisplay()
    if showMarker {
      markersContainer.updateMarkers()
    }
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
    // markerContainer
    if showMarker {
      let dx = (contentView.frame.minX - scrollView.contentOffset.x) - markersContainer.frame.minX
      markersContainer.frame = markersContainer.frame.offsetBy(dx: dx, dy: 0)
      markersContainer.contentOffsetDidChange(dx: scrollView.contentOffset.x - lastScrollContentOffset)
    }

    // contentView and guideView

    let contentOffset = max(0, min(scrollView.contentSize.width, scrollView.contentOffset.x))
    let scrollDirection = self.scrollDirection(newContentOffset: contentOffset)
    lastScrollContentOffset = contentOffset

    guageView.contentOffset = scrollView.contentOffset.x
    contentView.update(contentOffset: contentOffset,
                       direction: scrollDirection)

    // delegate

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

// MARK: - Marker management

extension RDMScrollableWaveformView {
  @objc private func addMarker() {
    markersContainer.addMarker(position: position)
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

class RDMWaveformScrollView: UIScrollView {
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  override init(frame: CGRect) {
    super.init(frame: frame)
  }
  override open func touchesShouldBegin(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) -> Bool {
    return true
  }
  override open func touchesShouldCancel(in view: UIView) -> Bool {
    return true
  }
}
