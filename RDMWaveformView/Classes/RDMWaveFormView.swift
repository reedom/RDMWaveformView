//
// Copyright 2013 - 2017, William Entriken and the RDMWaveformView contributors.
//

import UIKit
import MediaPlayer
import AVFoundation
import SparseRanges

public enum RDMWaveformResolution {
  case byViewWidth(scale: CGFloat, lineWidth: CGFloat, stride: CGFloat)
  case perSecond(width: Int, lineWidth: CGFloat, lines: Int)
}

/// A view for rendering audio waveforms
// IBDesignable support in XCode is so broken it's sad
open class RDMWaveformView: UIView {
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

  // MARK: - Properties

  /// A delegate to accept progress reporting
  open weak var delegate: RDMWaveformViewDelegate?

  /// Whether loading is happening asynchronously
  open var loadingInProgress = false

  /// The audio URL to render
  open var audioURL: URL? {
    didSet {
      guard let audioURL = audioURL else {
        NSLog("RDMWaveformView received nil audioURL")
        audioContext = nil
        return
      }

      // Start downloading
      loadingInProgress = true
      delegate?.waveformViewWillLoad?(self)

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
          self.loadingInProgress = false
          self.delegate?.waveformViewDidLoad?(self)
        }
      }
    }
  }

  /// `scrollView` contains `contentView` and `guageView`.
  open lazy var scrollView: UIScrollView = {
    let scrollView = UIScrollView(frame: bounds)
    scrollView.backgroundColor = marginBackgroundColor
    addSubview(scrollView)
    scrollView.delegate = self
    return scrollView
  }()

  /// `contentView` renders a waveform.
  public lazy var contentView: RDMWaveformContentView = {
    let contentView = RDMWaveformContentView()
    contentView.resolution = waveformContentResolution
    contentView.backgroundColor = waveformBackgroundColor
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
      guard let audioContext = audioContext else { return 0 }
      return TimeInterval(_position) / TimeInterval(audioContext.sampleRate)
    }
    set {
      guard let audioContext = audioContext else { return }
      position = Int(newValue * TimeInterval(audioContext.sampleRate))
    }
  }

  /// The current position in the sampling data that the waveform points at.
  private var _position: Int = 0
  public var position: Int {
    get { return _position }
    set {
      _position = max(0, min(totalSamples, newValue))
      guard 0 < totalSamples else { return }
      // Update view position
      let x = contentView.frame.width * CGFloat(time / duration.seconds)
      scrollView.contentOffset = CGPoint(x: x, y: 0)
    }
  }

  /// The samples to be highlighted in a different color
  open var markers = [RDMMarker]() {
    didSet {
      guard audioContext != nil else { return }
      setNeedsLayout()
    }
  }

  public var waveformBackgroundColor = UIColor(red: 26/255, green: 25/255, blue: 31/255, alpha: 1) {
    didSet {
      contentView.backgroundColor = marginBackgroundColor
    }
  }


  public var marginBackgroundColor = UIColor(red: 18/255, green: 18/255, blue: 20/255, alpha: 1) {
    didSet {
      scrollView.backgroundColor = marginBackgroundColor
    }
  }

  public var waveformContentResolution = RDMWaveformResolution.perSecond(width: 100, lineWidth: 1, lines: 25) {
    didSet {
      contentView.resolution = waveformContentResolution
      setNeedsLayout()
    }
  }

  public var waveformContentAlignment = WaveformAlignment.center {
    didSet {
      setNeedsLayout()
    }
  }

  // Mark - helper properties

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

  // Mark - Private vars

  /// Current audio context to be used for rendering
  private var audioContext: RDMAudioContext? {
    didSet {
      contentView.audioContext = audioContext
      reset()
      setNeedsLayout()
    }
  }

  override open func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    if newWindow == nil {
      contentView.cancel()
    }
  }

  deinit {
    contentView.cancel()
  }

  override open func layoutSubviews() {
    super.layoutSubviews()
    scrollView.frame = bounds

    guard let audioContext = audioContext else {
      // TODO show empty view
      return
    }

    var waveformWidth: CGFloat

    switch waveformContentResolution {
    case .byViewWidth(let scale, _, _):
      waveformWidth = scrollView.frame.width * scale
    case .perSecond(let widthPerSecond, _, _):
      waveformWidth = CGFloat(widthPerSecond) * CGFloat(audioContext.asset.duration.seconds)
    }

    scrollView.contentSize = CGSize(width: ceil(waveformWidth + contentMargin * 2),
                                    height: scrollView.frame.height)
    if guageView.isHidden {
      contentView.marginLeft = contentMargin
      contentView.frame = CGRect(x: ceil(contentMargin),
                                 y: 0,
                                 width: waveformWidth,
                                 height: scrollView.contentSize.height)
    } else {
      contentView.marginLeft = contentMargin
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
    contentView.update(visibleWidth: scrollView.frame.width,
                       contentOffset: scrollView.contentOffset.x,
                       direction: .none)
  }

  // MARK: - Waveform content management

  public func reset() {
    contentView.reset()
    guageView.reset()
  }

  private func refresh() {
    guageView.refresh()
  }

  // MARK: - handle scrolling

  private var lastScrollContentOffset: CGFloat = 0

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

// MARK: - view lifecycle
extension RDMWaveformView {
  override open func didMoveToSuperview() {
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(appWillEnterForeground(notification:)),
                                           name: UIApplication.willEnterForegroundNotification,
                                           object: nil)
  }

  override open func willMove(toSuperview newSuperview: UIView?) {
    if newSuperview == nil {
      NotificationCenter.default.removeObserver(self)
    }
  }

  @objc private func appWillEnterForeground(notification: Notification) {
    refresh()
  }
}

// MARK: - UIScrollViewDelegate
extension RDMWaveformView: UIScrollViewDelegate {
  // any offset changes
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let contentOffset = max(0, min(scrollView.contentSize.width, scrollView.contentOffset.x))
    let scrollDirection = self.scrollDirection(newContentOffset: contentOffset)
    lastScrollContentOffset = contentOffset

    guageView.contentOffset = scrollView.contentOffset.x
    contentView.update(visibleWidth: scrollView.frame.width,
                       contentOffset: contentOffset,
                       direction: scrollDirection)
  }
}

/// To receive progress updates from RDMWaveformView
@objc public protocol RDMWaveformViewDelegate: NSObjectProtocol {
  /// An audio file will be loaded
  @objc optional func waveformViewWillLoad(_ waveformView: RDMWaveformView)

  /// An audio file was loaded
  @objc optional func waveformViewDidLoad(_ waveformView: RDMWaveformView)

  /// Rendering will begin
  @objc optional func waveformViewWillDownsample(_ waveformView: RDMWaveformView)

  /// Rendering did complete
  @objc optional func waveformViewDidDownsample(_ waveformView: RDMWaveformView)

  /// Rendering will begin
  @objc optional func waveformViewWillRender(_ waveformView: RDMWaveformView?)

  /// Rendering did complete
  @objc optional func waveformViewDidRender(_ waveformView: RDMWaveformView?)

  /// The scrubbing gesture will start
  @objc optional func waveformWillStartScrubbing(_ waveformView: RDMWaveformView)

  /// The scrubbing gesture scrubbing
  @objc optional func waveformScrubbing(_ waveformView: RDMWaveformView)

  /// The scrubbing gesture did end
  @objc optional func waveformDidEndScrubbing(_ waveformView: RDMWaveformView)
}
