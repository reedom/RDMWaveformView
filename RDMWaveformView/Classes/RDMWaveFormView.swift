//
//  RDMWaveformView.swift
//  RDMWaveformView
//
//  Created by HANAI Tohru on 4/14/19.
//  Copyright © 2019 reedom. All rights reserved.
//

import UIKit
import MediaPlayer
import AVFoundation
import SparseRanges

public typealias SampleRange = CountableRange<Int>
public typealias DownsampleRange = CountableRange<Int>
public typealias TimeRange = CountableRange<Int>
public typealias ViewRange = CountableRange<Int>

/// A view for rendering audio waveforms
// IBDesignable support in XCode is so broken it's sad
open class RDMWaveformView: UIView {

  // MARK: - Properties

  /// `RDMWaveformController` holds `audioContenxt` and `currentTime`.
  open var controller: RDMWaveformController? {
    willSet {
      controller?.unsubscribe(self)
    }
    didSet {
      controller?.subscribe(self)
      refreshWaveform()
    }
  }

  /// `RDMWaveformMarkersController` manages markers.
  public var markersController: RDMWaveformMarkersController? {
    get { return markersContainer.markersController }
    set { markersContainer.markersController = newValue }
  }

  /// If the audio track duration is shorter than this value,
  /// the `RDMAudioDownsampler` will automatically downsample
  /// entire track.
  private var _preloadIfTrackShorterThan: TimeInterval = 5*60
  open var preloadIfTrackShorterThan: TimeInterval {
    get { return _preloadIfTrackShorterThan }
    set {
      _preloadIfTrackShorterThan = newValue
      downsampler?.preloadIfTrackShorterThan = newValue
    }
  }

  /// Specifies whether the user can change the "currentTime" by tapping or scrubbing.
  open var timeSeekEnabled = true

  /// Maximum decibel in a audio track.
  public var decibelMin: CGFloat = -50
  /// Minimum decibel in a audio track.
  public var decibelMax: CGFloat = -10

  // MARK: - Appearance properties

  /// The color of the waveform's lines
  public var waveformLineColor: UIColor = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)

  /// The background color of the waveform area.
  public var waveformBackgroundColor = UIColor(red: 26/255, green: 25/255, blue: 31/255, alpha: 1) {
    didSet {
      contentView.backgroundColor = waveformBackgroundColor
    }
  }

  public struct WaveformRenderOptions {
    let stride: CGFloat
    let lineWidth: CGFloat
  }

  public var waveformRenderOptions = WaveformRenderOptions(stride: 1, lineWidth: 1)

  private var resolution: RDMWaveformResolution {
    return .byViewWidth(stride: waveformRenderOptions.stride,
                        lineWidth: waveformRenderOptions.lineWidth)
  }

  /// Indicates whether to show the cursor.
  public var showCursor = true {
    didSet {
      cursorView.isHidden = !showCursor
      setNeedsLayout()
    }
  }

  /// Width of the cursor.
  public var cursorWidth: CGFloat = 3

  // MARK: - Subviews

  /// `contentView` renders a waveform.
  public lazy var contentView: RDMWaveformContentView = {
    let view = RDMWaveformContentView()
    view.backgroundColor = waveformBackgroundColor
    view.contentMode = .redraw
    addSubview(view)
    return view
  }()

  public lazy var cursorView: RDMWaveformCursor = {
    let view = RDMWaveformCursor()
    addSubview(view)
    view.isHidden = !showCursor
    return view
  }()

  public lazy var markersContainer: RDMWaveformMarkersContainer = {
    let view = RDMWaveformMarkersContainer()
    addSubview(view)
    view.backgroundColor = UIColor.transparent
    view.markerSize = CGSize(width: 4, height: 4)
    view.markerTouchSize = view.markerSize
    view.markerLineColor = UIColor.transparent
    view.draggable = false
    return view
  }()

  // MARK: - Subview on/off

  open var showMarker: Bool {
    get { return !markersContainer.isHidden }
    set {
      markersContainer.isHidden = !newValue
      setNeedsLayout()
    }
  }

  // MARK: - State properties

  /// Downsampler.
  private var downsampler: RDMAudioDownsampler?
  /// Waveform calculator
  private var calculator: RDMWaveformCalc!

  // MARK: - initialization

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setup()
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  private func setup() {
    contentView.isHidden = false
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    addGestureRecognizer(tapGestureRecognizer)
    let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
    addGestureRecognizer(panGestureRecognizer)
  }

  deinit {
    debugPrint("RDMWaveformView.deinit")
    controller?.unsubscribe(self)
    downsampler?.cancel()
  }

  // MARK: - view lifecycle

  override open func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    if newWindow == nil {
      downsampler?.cancel()
    }
  }

  override open func layoutSubviews() {
    super.layoutSubviews()

    setupContentView()

    // contentView

    if showMarker {
      contentView.frame = CGRect(x: 0,
                                 y: markersContainer.markerSize.height,
                                 width: bounds.width,
                                 height: bounds.height - markersContainer.markerSize.height)
    } else {
      contentView.frame = bounds
    }

    if !cursorView.isHidden {
      contentView.frame = contentView.frame.insetBy(dx: cursorWidth / 2, dy: 0)
      updateCursor()
      bringSubviewToFront(cursorView)
      cursorView.setNeedsDisplay()
    }
    if showMarker {
      markersContainer.markerLineHeight = contentView.frame.height
      markersContainer.frame = CGRect(x: contentView.frame.minX,
                                      y: 0,
                                      width: contentView.frame.width,
                                      height: markersContainer.markerSize.height)
    }

    if let controller = controller, controller.hasAudio {
      let duration = controller.audioContext!.asset.duration.seconds
      contentView.cancelRendering()
      contentView.startRenderingProcedure(timeRange: 0..<Int(ceil(duration)))
    } else {
      // TODO clear contentView
    }
  }
}

// MARK: - Waveform content management

extension RDMWaveformView {
  private func refreshWaveform() {
    // contentView.reset()
    markersContainer.duration = controller?.audioContext?.asset.duration.seconds ?? 0
    setNeedsLayout()
  }

  private func setupContentView() {
    setupCalculator()
    setupDownsampler()

    contentView.calculator = calculator
    contentView.downsampler = downsampler
    contentView.cancelRendering()
    if let calculator = calculator, let downsampler = downsampler {
      contentView.rendererParams = RDMWaveformRendererParams(decibelMin: downsampler.decibelMin,
                                                             decibelMax: downsampler.decibelMax,
                                                             resolution: calculator.resolution,
                                                             totalWidth: calculator.totalWidth,
                                                             marginLeft: 0,
                                                             lineColor: waveformLineColor)
    }
  }

  private func setupCalculator() {
    if let calculator = calculator {
      if calculator.totalWidth == frame.width {
        // no need to recreate
        return
      }
    }

    guard let audioContext = controller?.audioContext else { return }
    calculator = RDMWaveformCalc(duration: audioContext.asset.duration.seconds,
                                 sampleRate: audioContext.sampleRate,
                                 resolution: resolution,
                                 totalWidth: frame.width)
  }

  private func setupDownsampler() {
    guard let calculator = calculator    else { return }
    if let downsampler = downsampler {
      if downsampler.downsampleRate == calculator.downsampleRate {
        // no need to recreate
        return
      }
    }

    guard let audioContext = controller?.audioContext else { return }
    downsampler = RDMAudioDownsampler(
      audioContext: audioContext,
      downsampleRate: calculator.downsampleRate,
      decibelMax: decibelMax,
      decibelMin: decibelMin,
      preloadIfTrackShorterThan: _preloadIfTrackShorterThan)
  }
}

// MARK: - Cursor

extension RDMWaveformView {
  @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
    guard
      timeSeekEnabled,
      let controller = controller,
      let duration = controller.audioContext?.asset.duration
      else { return }
    let progress = recognizer.location(in: self).x / bounds.width
    let time = Double(progress) * duration.seconds
    controller.updateTime(time, excludeNotify: self)
    updateCursor()
  }

  @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
    guard
      timeSeekEnabled,
      let controller = controller,
      let duration = controller.audioContext?.asset.duration
      else { return }

    switch recognizer.state {
    case .began:
      controller.enterSeekMode()
    case .ended, .cancelled:
      controller.leaveSeekMode()
    case .changed:
      let progress = recognizer.location(in: self).x / bounds.width
      let time = Double(progress) * duration.seconds
      controller.updateTime(time, excludeNotify: self)
      updateCursor()
    default:
      return
    }
  }

  private func updateCursor() {
    guard
      !cursorView.isHidden,
      let duration = controller?.audioContext?.asset.duration,
      let time = controller?.currentTime
      else { return }
    let progress = time / duration.seconds
    cursorView.frame = CGRect(x: frame.width * CGFloat(progress),
                              y: 0,
                              width: cursorWidth,
                              height: bounds.height)
  }
}

// MARK: - RDMWaveformControllerDelegate

extension RDMWaveformView: RDMWaveformControllerDelegate {
  public func waveformControllerWillLoadAudio(_ controller: RDMWaveformController) {

  }

  public func waveformControllerDidLoadAudio(_ controller: RDMWaveformController) {
    refreshWaveform()
  }

  public func waveformController(_ controller: RDMWaveformController, didUpdateTime time: TimeInterval, seekMode: Bool) {
    updateCursor()
  }

  public func waveformControllerDidReset(_ controller: RDMWaveformController) {

  }
}
