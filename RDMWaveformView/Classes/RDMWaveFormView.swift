//
// Copyright 2013 - 2017, William Entriken and the RDMWaveformView contributors.
//

import UIKit
import MediaPlayer
import AVFoundation
import SparseRanges

public struct RDMMarker {
  let position: CGFloat
  let name: String
}

public enum RDMWaveformResolution {
  case entireTrack(lineWidth: Int, stride: Int)
  case second(widthPerSecond: Int, linesPerSecond: Int, lineWidth: Int)
}

public enum RDMWaveformPositionAlignment {
  case none
  case center
}

/// A view for rendering audio waveforms
// IBDesignable support in XCode is so broken it's sad
open class RDMWaveformView: UIView {

  private enum ScrollDirection {
    case none
    case forward
    case backward
  }

  /// A delegate to accept progress reporting
  open weak var delegate: RDMWaveformViewDelegate? {
    didSet {
      contentView.delegate = delegate
    }
  }

  /// Whether loading is happening asynchronously
  open var loadingInProgress = false

  /// The audio file to render
  open var audioURL: URL? {
    didSet {
      guard let audioURL = audioURL else {
        NSLog("RDMWaveformView received nil audioURL")
        audioContext = nil
        return
      }

      loadingInProgress = true
      delegate?.waveformViewWillLoad?(self)

      RDMAudioContext.load(fromAudioURL: audioURL) { audioContext in
        DispatchQueue.main.async {
          guard self.audioURL == audioContext?.audioURL else { return }

          if audioContext == nil {
            print("RDMWaveformView failed to load URL: \(audioURL)")
          } else {
            print("duration: \(audioContext!.asset.duration.seconds)secs")
          }

          self.audioContext = audioContext // This will reset the view and kick off a layout

          self.loadingInProgress = false
          self.delegate?.waveformViewDidLoad?(self)
        }
      }
    }
  }

  open lazy var scrollView: UIScrollView = {
    let scrollView = UIScrollView(frame: bounds)
    scrollView.backgroundColor = marginBackgroundColor
    addSubview(scrollView)
    scrollView.delegate = self
    return scrollView
  }()

  public lazy var contentView: RDMWaveformContentView = {
    let contentView = RDMWaveformContentView()
    contentView.backgroundColor = waveformBackgroundColor
    scrollView.addSubview(contentView)
    return contentView
  }()

  public lazy var guageView: RDMWaveformTimeGuageView = {
    let guageView = RDMWaveformTimeGuageView()
    guageView.backgroundColor = marginBackgroundColor
    scrollView.addSubview(guageView)
    return guageView
  }()

  /// The total number of audio samples in the file
  public var totalSamples: Int {
    return audioContext?.totalSamples ?? 0
  }

  public var duration: CMTime {
    return audioContext?.asset.duration ?? CMTime.zero
  }

  private var _time = CMTime.zero

  public var time: CMTime {
    get { return _time }
    set { _time = newValue }
  }

  private var _position: Int = 0
  public var position: Int {
    get { return _position }
    set { _position = newValue }
  }

  /// The samples to be highlighted in a different color
  open var markers = [RDMMarker]() {
    didSet {
      guard 0 < totalSamples else { return }
      setNeedsLayout()
    }
  }

  public var renderingUnitFactor: Float = 1.5

  public var waveformBackgroundColor = UIColor(red: 18/255, green: 18/255, blue: 20/255, alpha: 1) {
    didSet {
      contentView.backgroundColor = waveformBackgroundColor
    }
  }

  public var marginBackgroundColor = UIColor(red: 18/255, green: 18/255, blue: 20/255, alpha: 1) {
    didSet {
      scrollView.backgroundColor = marginBackgroundColor
    }
  }

  public var waveformContentResolution = RDMWaveformResolution.second(widthPerSecond: 100, linesPerSecond: 25, lineWidth: 1)
  public var waveformContentAlignment = RDMWaveformPositionAlignment.center

  private var contentMargin: CGFloat {
    return waveformContentAlignment == .center ? scrollView.frame.width / 2 : 0
  }

  // Mark - Private vars

  /// The "zero" level (in dB)
  private var decibelMin: CGFloat = -50.0
  private var decibelMax: CGFloat = -10.0

  /// Operations in progress
  private var operations = [RDMWaveformLoadOperation]()
  private var renderSources = [RDMWaveformRenderSource]()

  private var renderedViewRanges = SparseCountableRange<Int>()

  public func reset() {
    renderedViewRanges.removeAll()
    contentView.reset()
    guageView.reset()
  }

  private func refresh() {
    renderedViewRanges.removeAll()
    guageView.refresh()
    invokeOperationIfNeeded(viewRange: normalizeViewRange(of: scrollView.contentOffset.x))
  }

  /// Current audio context to be used for rendering
  private var audioContext: RDMAudioContext? {
    didSet {
      reset()
      setNeedsLayout()
    }
  }

  deinit {
    operations.forEach { $0.cancel() }
  }

  override open func layoutSubviews() {
    super.layoutSubviews()
    scrollView.frame = bounds

    guard let audioContext = audioContext else {
      // TODO show empty view
      return
    }

    var contentWidth: CGFloat
    let contentHeight = scrollView.frame.height

    switch waveformContentResolution {
    case .entireTrack(_, _):
      contentWidth = scrollView.frame.width
    case .second(let widthPerSecond, _, _):
      contentWidth = CGFloat(widthPerSecond) * CGFloat(audioContext.asset.duration.seconds)
    }

    scrollView.contentSize = CGSize(width: ceil(contentWidth + contentMargin * 2),
                                    height: contentHeight)
    if guageView.isHidden {
      contentView.frame = CGRect(x: ceil(contentMargin),
                                 y: 0,
                                 width: contentWidth,
                                 height: contentHeight)
    } else {
      contentView.frame = CGRect(x: ceil(contentMargin),
                                 y: 0,
                                 width: contentWidth,
                                 height: contentHeight - guageView.areaHeight)
      guageView.marginLeft = contentMargin
      guageView.frame = CGRect(x: guageView.labelPaddingLeft,
                               y: contentView.frame.maxY,
                               width: scrollView.contentSize.width + scrollView.frame.width,
                               height: guageView.areaHeight)
    }

    updateWaveformUnitWidth()
    invokeOperationIfNeeded(viewRange: normalizeViewRange(of: 0))
    renderGuage(.none)
  }

  private func updateWaveformUnitWidth() {
    switch waveformContentResolution {
    case .entireTrack(_, _):
      waveformUnitWidth = Int(scrollView.frame.width)
    case .second(let widthPerSecond, _, _):
      let unitWidth = Int(Float(scrollView.frame.width) * renderingUnitFactor)
      let remaining = unitWidth % widthPerSecond
      if 0 < remaining {
        waveformUnitWidth = unitWidth + widthPerSecond - remaining
      } else {
        waveformUnitWidth = unitWidth
      }
    }
  }

  // MARK: - handle scrolling

  private var waveformUnitWidth: Int = 0
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

// MARK: - guage

extension RDMWaveformView {
  private func renderGuage(_ scrollDirection: ScrollDirection) {
    guard !guageView.isHidden else { return }

    let x = Int(scrollView.contentOffset.x)
    let width = Int(scrollView.frame.width)
    switch scrollDirection {
    case .forward:
      guageView.add(viewRange: x..<x+width)
    case .backward:
      guageView.add(viewRange: x-width..<x)
    case .none:
      guageView.add(viewRange: x-width..<x+width)
    }
  }
}

// MARK: - waveform rendering calculation

extension RDMWaveformView {
  private typealias ViewRange = CountableRange<Int>

  /// Calculate view range of the specific x position of the view, in pixel.
  private func normalizeViewRange(of x: CGFloat) -> ViewRange {
    switch waveformContentResolution {
    case .entireTrack(_, _):
      return 0 ..< Int(contentView.frame.width)
    case .second(_, _, _):
      let x1 = max(0, waveformUnitWidth * (Int(round(x)) / waveformUnitWidth))
      return x1 ..< min(Int(contentView.frame.width), x1 + waveformUnitWidth)
    }
  }

  private func prevViewRange(of viewRange: ViewRange) -> ViewRange {
    switch waveformContentResolution {
    case .entireTrack(_, _):
      return viewRange
    case .second(_, _, _):
      let x = max(0, min(viewRange.lowerBound, Int(contentView.frame.width)) - waveformUnitWidth)
      return x ..< min(Int(contentView.frame.width), x + waveformUnitWidth)
    }
  }

  private func nextViewRange(of viewRange: ViewRange) -> ViewRange {
    switch waveformContentResolution {
    case .entireTrack(_, _):
      return viewRange
    case .second(_, _, _):
      let x = min(Int(contentView.frame.width), max(0, viewRange.upperBound) + waveformUnitWidth)
      return max(0, x - waveformUnitWidth) ..< x
    }
  }

  private func sampleRangeFor(contentPosX: CGFloat) -> Int {
    return max(0, min(totalSamples, totalSamples * Int(contentPosX / contentView.frame.width)))
  }

  private func sampleRangeFor(contentPosX: Int) -> Int {
    return max(0, min(totalSamples, totalSamples * contentPosX / Int(contentView.frame.width)))
  }

  private func sampleRangeFor(viewRange: ViewRange) -> ViewRange {
    let x1 = sampleRangeFor(contentPosX: viewRange.lowerBound)
    let x2 = sampleRangeFor(contentPosX: viewRange.upperBound)
    return x1..<x2
  }
}

// MARK: - UIScrollViewDelegate
extension RDMWaveformView: UIScrollViewDelegate {
  // any offset changes
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    renderIfNeeded()
  }

  private func renderIfNeeded() {
    let contentOffset = max(0, min(scrollView.contentSize.width, scrollView.contentOffset.x))
    let scrollDirection = self.scrollDirection(newContentOffset: contentOffset)
    guard scrollDirection != .none else { return }
    renderGuage(scrollDirection)

    defer {
      lastScrollContentOffset = contentOffset
    }

    let viewRange = normalizeViewRange(of: contentOffset)
    invokeOperationIfNeeded(viewRange: viewRange)

    switch scrollDirection {
    case .forward:
      invokeOperationIfNeeded(viewRange: nextViewRange(of: viewRange))
    case .backward:
      invokeOperationIfNeeded(viewRange: prevViewRange(of: viewRange))
    case .none:
      return
    }
  }
}

// MARK: - Operation

extension RDMWaveformView {

  private func invokeOperationIfNeeded(viewRange: ViewRange) {
    guard audioContext != nil else { return }

    if let gaps = renderedViewRanges.gaps(viewRange) {
      renderedViewRanges.add(viewRange)
      gaps.forEach { invokeOperation(viewRange: $0) }
    }
  }

  private func invokeOperation(viewRange: ViewRange) {
    guard let audioContext = audioContext else { return }

    delegate?.waveformViewWillDownsample?(self)

    let targetRect: CGRect
    let calculator: RDMWaveformCalculator
    switch waveformContentResolution {
    case .entireTrack(let lineWidth, let stride):
      targetRect = contentView.frame
      calculator = RDMWaveformEntireTrackCalculator(audioContext: audioContext,
                                                    targetRect: targetRect,
                                                    lineWidth: lineWidth,
                                                    lineStride: stride)
    case .second(let widthPerSecond, let linesPerSecond, let lineWidth):
      let sampleRange = sampleRangeFor(viewRange: viewRange)
      targetRect = CGRect(x: CGFloat(viewRange.lowerBound),
                          y: 0,
                          width: CGFloat(viewRange.count),
                          height: contentView.frame.height)
      calculator = RDMWaveformPerSecondCalculator(audioContext: audioContext,
                                                  sampleRange: sampleRange,
                                                  targetRect: targetRect,
                                                  widthPerSecond: widthPerSecond,
                                                  linesPerSecond: linesPerSecond,
                                                  lineWidth: lineWidth)
    }

    let operation = RDMWaveformLoadOperation(calculator: calculator,
                                             decibelMin: decibelMin,
                                             decibelMax: decibelMax) { [weak self] renderSource in
                                              DispatchQueue.main.async {
                                                guard let self = self else { return }
                                                self.delegate?.waveformViewDidDownsample?(self)
                                                self.operations.removeAll(where: { $0.calculator.sampleRange == calculator.sampleRange })
                                                if let renderSource = renderSource {
                                                  self.contentView.add(renderSource: renderSource)
                                                }
                                                // self.delegate?.waveformViewDidRender?(self)
                                              }
    }

    self.operations.append(operation)
    // delegate?.waveformViewWillRender?(self)
    operation.start()
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

//MARK -

extension CountableRange where Bound: Strideable {

  // Extend each bound away from midpoint by `factor`, a portion of the distance from begin to end
  func extended(byFactor factor: Double) -> CountableRange<Bound> {
    let theCount: Int = numericCast(count)
    let amountToMove: Bound.Stride = numericCast(Int(Double(theCount) * factor))
    return lowerBound.advanced(by: -amountToMove) ..< upperBound.advanced(by: amountToMove)
  }
}
