//
// Copyright 2013 - 2017, William Entriken and the RDMWaveformView contributors.
//
import UIKit
import MediaPlayer
import AVFoundation

public struct RDMMarker {
  let position: CGFloat
  let name: String
}

public enum RDMWaveformPositionAlignment {
  case none
  case center
}

fileprivate class RDMWaveformImageController {
  deinit {
    inProgressWaveformRenderOperation?.cancel()
  }

  // MARK: - Properties

  private var _attributes: RDMWaveformAttributes?
  var attributes: RDMWaveformAttributes? {
    get { return _attributes }
  }

  private var _calculator: RDMWaveformCalculator?
  var calculator: RDMWaveformCalculator? {
    get { return _calculator }
  }

  var frame: CGRect {
    get { return imageView.frame }
    set { imageView.frame = newValue }
  }

  var isHidden: Bool {
    get { return imageView.isHidden }
    set { imageView.isHidden = newValue }
  }

  /// View for rendered waveform
  lazy fileprivate var imageView: UIImageView = {
    let retval = UIImageView(frame: CGRect.zero)
    retval.contentMode = .scaleToFill
    return retval
  }()

  /// Image of waveform
  fileprivate var waveformImage: UIImage? {
    get { return imageView.image }
    set {
      // This will allow us to apply a tint color to the image
      imageView.image = newValue?.withRenderingMode(.alwaysTemplate)
    }
  }

  // MARK: - Properties of operation

  /// Currently running renderer
  private var inProgressWaveformRenderOperation: RDMWaveformLoadOperation? {
    willSet {
      if newValue !== inProgressWaveformRenderOperation {
        inProgressWaveformRenderOperation?.cancel()
      }
    }
  }

  /// Whether rendering for the current asset failed
  private var renderForCurrentAssetFailed = false

  /// Whether rendering is happening asynchronously
  fileprivate var renderingInProgress = false

  /// Represents the status of the waveform renderings
  fileprivate enum CacheStatus {
    case dirty
    case notDirty(cancelInProgressRenderOperation: Bool)
  }

  /// MARK: - Rendering
  func render(attributes: RDMWaveformAttributes, calculator: RDMWaveformCalculator) {
    let operation = RDMWaveformLoadOperation(attributes: attributes, calculator: calculator) { [weak self] image in
      DispatchQueue.main.async {
        guard let self = self else { return }

        self.renderForCurrentAssetFailed = (image == nil)
        // This will allow us to apply a tint color to the image
        self.waveformImage = image?.withRenderingMode(.alwaysTemplate)
        self.imageView.frame = CGRect(origin: self.imageView.frame.origin, size: calculator.viewSize)
        self.imageView.isHidden = false
        self.renderingInProgress = false
        self.inProgressWaveformRenderOperation = nil
        print("sampleRange: \(calculator.sampleRange)")
        print("frame: \(self.imageView.frame)")
        // self.delegate?.waveformViewDidRender?(self)
      }
    }
    self.inProgressWaveformRenderOperation = operation
    self._attributes = attributes
    self._calculator = calculator

    renderingInProgress = true
    // delegate?.waveformViewWillRender?(self)
    operation.start()
  }
}

/// A view for rendering audio waveforms
// IBDesignable support in XCode is so broken it's sad
open class RDMWaveformView: UIView {
  /// A delegate to accept progress reporting
  open weak var waveformdelegate: RDMWaveformViewDelegate?

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
      waveformdelegate?.waveformViewWillLoad?(self)

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
          self.waveformdelegate?.waveformViewDidLoad?(self)
        }
      }
    }
  }

  open var waveformResolution = RDMWaveformResolution.second(widthPerSecond: 100, linesPerSecond: 25, lineWidth: 1)

  /// The total number of audio samples in the file
  open var totalSamples: Int {
    return audioContext?.totalSamples ?? 0
  }

  /// The samples to be highlighted in a different color
  open var markers = [RDMMarker]() {
    didSet {
      guard 0 < totalSamples else { return }
      setNeedsLayout()
    }
  }

  /// The color of the waveform
  open var wavesColor = UIColor.black {
    didSet {
      imageControllers.forEach({ $0.imageView.tintColor = wavesColor })
    }
  }

  /// The "zero" level (in dB)
  fileprivate let noiseFloor: CGFloat = -50.0

  // Mark - Private vars

  /// Current audio context to be used for rendering
  private var audioContext: RDMAudioContext? {
    didSet {
      resetWaveformImages()
    }
  }

  open var waveformAlignment = RDMWaveformPositionAlignment.none

  public var scrollView: UIScrollView!
  public var waveformsView: UIView!
  public var guageView: UIView?

  /// Waveforms
  fileprivate var imageControllers: [RDMWaveformImageController]!

  fileprivate enum ScrollDirection {
    case none
    case forward
    case backward
  }

  /// Gesture recognizer
  fileprivate var tapRecognizer = UITapGestureRecognizer()

  required public init?(coder aCoder: NSCoder) {
    super.init(coder: aCoder)
    setup()
  }

  override init(frame rect: CGRect) {
    super.init(frame: rect)
    setup()
  }

  override open func layoutSubviews() {
    super.layoutSubviews()
    scrollView.frame = bounds
    resetWaveformImages()
  }

  let waveformMarginColor = UIColor(red: 18/255, green: 18/255, blue: 20/255, alpha: 1)
  let waveformBackgroundColor = UIColor(red: 18/255, green: 18/255, blue: 20/255, alpha: 1)

  func setup() {
    scrollView = UIScrollView(frame: bounds)
    scrollView.backgroundColor = waveformMarginColor
    addSubview(scrollView)
    scrollView.delegate = self

    waveformsView = UIView(frame: bounds)
    scrollView.addSubview(waveformsView)
    waveformsView.backgroundColor = waveformBackgroundColor

    imageControllers = (0..<3).map { _ in
      let controller = RDMWaveformImageController()
      controller.isHidden = true
      waveformsView.addSubview(controller.imageView)
      return controller
    }

    tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture))
    addGestureRecognizer(tapRecognizer)
  }

  private func resetWaveformImages() {
    imageControllers.forEach { $0.isHidden = true }

    guard let audioContext = audioContext else { return }

    var contentWidth: CGFloat
    var contentMargin: CGFloat

    switch waveformResolution {
    case .entireTrack(_, _):
      contentWidth = scrollView.frame.width
      contentMargin = waveformAlignment == .center ? scrollView.frame.width / 2 : 0
    case .second(let widthPerSecond, _, _):
      contentWidth = CGFloat(widthPerSecond) * CGFloat(audioContext.asset.duration.seconds)
      contentMargin = waveformAlignment == .center ? scrollView.frame.width / 2 : 0
    }

    var contentHeight = scrollView.frame.height
    if let guageView = guageView {
      guageView.frame = CGRect(x: contentMargin,
                               y: scrollView.frame.height - guageView.frame.height,
                               width: contentWidth + contentMargin + 100,
                               height: guageView.frame.height)
      contentHeight -= guageView.frame.height
      scrollView.addSubview(guageView)
    }
    scrollView.contentSize = CGSize(width: ceil(contentWidth + contentMargin * 2),
                                    height: scrollView.frame.height)
    waveformsView.frame = CGRect(x: ceil(contentMargin),
                                 y: 0,
                                 width: contentWidth,
                                 height: contentHeight)
    setup(controller: imageControllers.first!, samplePosition: 0)
  }

  private func setup(controller: RDMWaveformImageController, samplePosition: Int) {
    controller.isHidden = true
    guard let audioContext = audioContext else { return }

    let attributes = RDMWaveformAttributes(wavesColor: wavesColor,
                                           noiseFloor: noiseFloor)
    switch waveformResolution {
    case .entireTrack(let lineWidth, let stride):
      let calculator = RDMWaveformEntireTrackCalculator(audioContext: audioContext,
                                                        viewSize: waveformsView.frame.size,
                                                        lineWidth: lineWidth,
                                                        lineStride: stride)
      controller.frame = waveformsView.bounds
      controller.render(attributes: attributes, calculator: calculator)
    case .second(let widthPerSecond, let linesPerSecond, let lineWidth):
      let frameSize = CGSize(width: scrollView.frame.width, height: waveformsView.frame.height)
      let calculator = RDMWaveformPerSecondCalculator(audioContext: audioContext,
                                                      samplePosition: samplePosition,
                                                      frameSize: frameSize,
                                                      widthPerSecond: widthPerSecond,
                                                      linesPerSecond: linesPerSecond,
                                                      lineWidth: lineWidth)
      let x = CGFloat(widthPerSecond) * CGFloat(calculator.time.seconds)
      controller.frame = CGRect(origin: CGPoint(x: x, y: 0), size: CGSize.zero)
      controller.render(attributes: attributes, calculator: calculator)
    }
  }

  // MARK: - handle scrolling

  fileprivate var lastScrollContentOffset: CGFloat = 0

  fileprivate func scrollDirection(_ newContentOffset: CGFloat) -> ScrollDirection {
    if lastScrollContentOffset < newContentOffset {
      return .forward
    } else if scrollView.contentOffset.x < lastScrollContentOffset {
      return .backward
    } else {
      return .none
    }
  }

  fileprivate func waveformImageControllerAt(contentOffset: CGFloat) -> RDMWaveformImageController? {
    return imageControllers.first(where: { (controller) -> Bool in
      guard !controller.imageView.isHidden else { return false }
      let point = CGPoint(x: contentOffset, y: controller.imageView.frame.minY)
      return controller.imageView.frame.contains(point)
    })
  }

  private func hasWaveformImageController(nextTo controller: RDMWaveformImageController,
                                          direction: ScrollDirection) -> Bool
  {
    return imageControllers.contains(where: { (c) -> Bool in
      guard !c.imageView.isHidden else { return false }
      switch direction {
      case .forward:
        return c.imageView.frame.minX == controller.imageView.frame.maxX
      case .backward:
        return c.imageView.frame.maxX == controller.imageView.frame.minX
      case .none:
        return true
      }
    })
  }

  private func reusableWaveformImageController(nextTo controller: RDMWaveformImageController,
                                               direction: ScrollDirection) -> RDMWaveformImageController {
    if let c = imageControllers.first(where: { $0.imageView.isHidden }) {
      return c
    }
    switch direction {
    case .forward:
      // find the leftmost controller
      return imageControllers.reduce(controller) { (result, c) in
        return result.imageView.frame.minX < c.imageView.frame.minX ? result : c
      }
    case .backward:
      // find the rightmost controller
      return imageControllers.reduce(controller) { (result, c) in
        return result.imageView.frame.maxX < c.imageView.frame.maxX ? c : result
      }
    case .none:
      return controller
    }
  }
}

extension RDMWaveformView: UIScrollViewDelegate {
  // any offset changes
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let contentOffset = max(0, scrollView.contentOffset.x)
    let scrollDirection = self.scrollDirection(contentOffset)

    defer {
      lastScrollContentOffset = contentOffset
    }

    if let controller = waveformImageControllerAt(contentOffset: contentOffset) {
      switch scrollDirection {
      case .forward:
        guard let hasNextPage = controller.calculator?.hasNextPage, hasNextPage else { return }
        let range = lastScrollContentOffset ..< scrollView.contentOffset.x
        if !range.contains(controller.imageView.frame.midX) {
          // no need to setup next waveform
          return
        }
        if hasWaveformImageController(nextTo: controller, direction: scrollDirection) {
          // Okay, we already have setup the next one
          return
        }
        // Setup the next one
        let nextController = reusableWaveformImageController(nextTo: controller, direction: scrollDirection)
        setup(controller: nextController, samplePosition: controller.calculator!.sampleRange.upperBound)
      case .backward:
        guard let hasPrevPage = controller.calculator?.hasPrevPage, hasPrevPage else { return }
        let range = scrollView.contentOffset.x ..< lastScrollContentOffset
        if !range.contains(controller.imageView.frame.midX) {
          // no need to setup next waveform
          return
        }
        if hasWaveformImageController(nextTo: controller, direction: scrollDirection) {
          // Okay, we already have setup the next one
          return
        }
        // Setup the next one
        let nextController = reusableWaveformImageController(nextTo: controller, direction: scrollDirection)
        let nextSamplePosition = max(0, controller.calculator!.sampleRange.lowerBound - controller.calculator!.sampleRange.count)
        setup(controller: nextController, samplePosition: nextSamplePosition)
      case .none:
        return
      }

    }
  }

  // any zoom scale changes
  public func scrollViewDidZoom(_ scrollView: UIScrollView) {
    print("scrollViewDidZoom: \(scrollView.zoomScale)")
  }
}

extension RDMWaveformView: UIGestureRecognizerDelegate {
  public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }

  @objc func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
    //    if doesAllowScrubbing {
    //      let rangeSamples = CGFloat(zoomSamples.count)
    //      // highlightedSamples = 0 ..< Int((CGFloat(zoomSamples.startIndex) + rangeSamples * recognizer.location(in: self).x / bounds.width))
    //      delegate?.waveformDidEndScrubbing?(self)
    //    }
  }
}

/// To receive progress updates from RDMWaveformView
@objc public protocol RDMWaveformViewDelegate: NSObjectProtocol {
  /// Rendering will begin
  @objc optional func waveformViewWillRender(_ waveformView: RDMWaveformView)

  /// Rendering did complete
  @objc optional func waveformViewDidRender(_ waveformView: RDMWaveformView)

  /// An audio file will be loaded
  @objc optional func waveformViewWillLoad(_ waveformView: RDMWaveformView)

  /// An audio file was loaded
  @objc optional func waveformViewDidLoad(_ waveformView: RDMWaveformView)

  /// The panning gesture did begin
  @objc optional func waveformDidBeginPanning(_ waveformView: RDMWaveformView)

  /// The panning gesture did end
  @objc optional func waveformDidEndPanning(_ waveformView: RDMWaveformView)

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
